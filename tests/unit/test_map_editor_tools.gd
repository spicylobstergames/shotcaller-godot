extends RefCounted

# =============================================================================
# Runtime editor tool tests (tests/unit/test_map_editor_tools.gd)
# =============================================================================
# Behavior tests for map/editor/map_editor.gd that unit-test its host logic
# headlessly by driving the real editor scene (the same shape the M4 scratch
# probe validated and the suite's asset test exercises): instantiate
# map_editor.tscn under the runner, click through UI signals and synthetic
# input events, and read back the edited scaffold — no awaits, so the sync
# unit harness accepts it, and no saves, so nothing touches user://maps.
#
# Coverage:
#   - "Mirror paint" toggle (M5): on = a stroke writes its mirrored twin cells
#     (M3 contract), off = only where clicked (asymmetric maps authorable).
#     Asserted by cell VALUES and an erase->paint sequence, never by scaffold
#     cell counts, so the test cannot be flaked by scaffold paint overlap.
#   - "Move things" mode (M5): drags a scaffold building and a lane point on
#     the 64px grid, one undo action per drag, undoes/redoes to the original
#     position, leaves no history entry for a no-motion grab, shows the
#     dragged lane in the overlay, coexists with the other tool toggles, and
#     exits on Escape.
# =============================================================================

const EditorScene = preload("res://map/editor/map_editor.tscn")
const LaneLogic = preload("res://addons/map_editor/lane_logic.gd")
const TileBrush = preload("res://addons/map_editor/tile_brush_logic.gd")


func run(harness) -> void:
	var editor: Node2D = (EditorScene as PackedScene).instantiate()
	harness.add_child(editor)
	_test_boot(harness, editor)
	if _booted(harness, editor):
		_test_mirror_toggle(harness, editor)
		_test_move_building(harness, editor)
		_test_move_lane_point(harness, editor)
		_test_move_wiring(harness, editor)
	editor.free()


# ---------------------------------------------------------------------------
# Boot: map root, defaults, and reset of the mirror teaching state
# ---------------------------------------------------------------------------

var _editor: Node2D = null


func _booted(harness, editor) -> bool:
	return editor != null and editor.map_root != null


func _test_boot(harness, editor) -> void:
	harness.check(editor.map_root == null, "the editor boots with no map")
	harness.check(ui_of(editor) != null, "the editor's tool panel exists")
	if editor.map_root != null:
		return
	ui_of(editor).new_map_requested.emit()
	harness.check(editor.map_root != null, "New map installs a scaffold to edit")
	if editor.map_root == null:
		return
	# Mirror defaults ON: a fresh session keeps the M3 twin-cell contract, and
	# the author opts OUT per map when they want asymmetry.
	harness.check(ui_of(editor).mirror_enabled() == true,
			"Mirror paint defaults to on (M3 twin-cell contract)")


# ---------------------------------------------------------------------------
# Mirror toggle: painted cells and their twins, gated by the UI toggle
# ---------------------------------------------------------------------------

func _test_mirror_toggle(harness, editor) -> void:
	var map: Node = editor.map_root
	var ui = ui_of(editor)
	var ground: TileMapLayer = TileBrush.layer_for_brush(map, "ground")
	harness.check(ground != null, "the ground brush resolves to a TileMapLayer")
	if ground == null:
		return
	ui.tile_mode_requested.emit(true)
	harness.check(editor.mode == "tile", "Paint tiles mode is active for stroke tests")

	# A fixed off-center target on the 64px lane grid, expressed in the ground
	# layer's own space and projected to a viewport point — no dependency on
	# where the camera centered the view.
	var canvas: Transform2D = editor.get_viewport().get_canvas_transform()
	var local_target := Vector2(192, 256)
	var layer_xform := LaneLogic.viewport_to_node_xform(ground, canvas)
	var viewport_target: Vector2 = layer_xform * local_target

	# What the host paints: the default block option is the FULL TILE, i.e.
	# paint_cells_for_local over the map's tile size.
	var block_cells := TileBrush.paint_cells_for_local(ground, local_target,
			_map_tile_px(map))
	harness.check(block_cells.size() > 0, "the full-tile block covers cells to paint")
	var painted_source := int(ui.selected_tile().get("source_id", -1))
	harness.check(painted_source >= 0, "the tile picker offered a paintable tile")

	# --- mirror ON: stroke paints the clicked block AND its twins ---
	editor._paint_at(viewport_target, false)
	editor._commit_pending()
	var mirrored_ok := true
	for cell in block_cells:
		if ground.get_cell_source_id(cell) != painted_source:
			mirrored_ok = false
		var twin := TileBrush.mirrored_cell(cell, TileBrush.cell_size_of(ground),
				TileBrush.mirror_size_for(ground))
		if twin != cell and ground.get_cell_source_id(twin) != painted_source:
			mirrored_ok = false
	harness.check(mirrored_ok, "a mirror-on stroke paints its block and the mirrored twins")

	# --- erase with mirroring ON clears BOTH sides (proves cells are empty) ---
	editor._paint_at(viewport_target, true)
	editor._commit_pending()
	var erased := _all_cells_empty(ground, block_cells)
	harness.check(erased, "an erase stroke clears the block and its twins")

	# --- mirror OFF: only the clicked block paints; twins stay empty ---
	ui._mirror_toggle.button_pressed = false
	harness.check(not ui.mirror_enabled(), "the Mirror paint toggle is off when pressed off")
	editor._paint_at(viewport_target, false)
	editor._commit_pending()
	var only_clicked := true
	for cell in block_cells:
		if ground.get_cell_source_id(cell) != painted_source:
			only_clicked = false
		var twin := TileBrush.mirrored_cell(cell, TileBrush.cell_size_of(ground),
				TileBrush.mirror_size_for(ground))
		if twin != cell and ground.get_cell_source_id(twin) != -1:
			only_clicked = false
	harness.check(only_clicked, "a mirror-off stroke paints only where clicked (twins stay empty)")

	# One undo step reverts the asymmetric stroke back to the erased state;
	# redo reapplies it.
	editor.undo()
	var undone := true
	for cell in block_cells:
		var twin := TileBrush.mirrored_cell(cell, TileBrush.cell_size_of(ground),
				TileBrush.mirror_size_for(ground))
		if ground.get_cell_source_id(cell) != -1 or ground.get_cell_source_id(twin) != -1:
			undone = false
	harness.check(undone, "one undo reverts the whole mirror-off stroke")
	editor.redo()
	var redone := true
	for cell in block_cells:
		if ground.get_cell_source_id(cell) != painted_source:
			redone = false
	harness.check(redone, "redo reapplies the mirror-off stroke")
	editor.undo()  # leave the map clean for the move tests

	# --- escape exits tile mode
	editor._unhandled_input(_key(KEY_ESCAPE))
	harness.check(editor.mode == "", "Escape exits tile mode")


# ---------------------------------------------------------------------------
# Move tool: buildings (scaffold-preplaced included)
# ---------------------------------------------------------------------------

func _test_move_building(harness, editor) -> void:
	var map: Node = editor.map_root
	var castle = map.get_node_or_null("buildings/blue/castle")
	harness.check(castle != null, "the scaffold has a pre-placed castle to move")
	if castle == null:
		return
	var team: Node2D = castle.get_parent()
	var canvas: Transform2D = editor.get_viewport().get_canvas_transform()
	var viewport_pos: Vector2 = LaneLogic.viewport_to_node_xform(team, canvas) * castle.position
	var orig: Vector2 = castle.position

	harness.check(editor.mode == "", "the editor starts a fresh mode for the move tests")
	ui_of(editor).move_mode_requested.emit(true)
	harness.check(editor.mode == "move", "move mode requested through the UI is active")
	harness.check(ui_of(editor)._move_toggle.button_pressed, "the Move things toggle is lit")

	editor._handle_move_input(_click(viewport_pos, true))
	harness.check(not editor._drag.is_empty(), "a click on a building grabs it for dragging")
	if editor._drag.is_empty():
		return
	harness.check(editor._drag.get("node") == castle, "the drag grabbed the castle")
	harness.check(editor._drag.get("orig") == orig, "the drag remembered the original position")

	var pushed := viewport_pos + Vector2(256, 128)
	editor._handle_move_input(_motion(pushed))
	var moved: Vector2 = castle.position
	harness.check(moved != orig, "dragging moves the building")
	harness.check(int(moved.x) % 64 == 0 and int(moved.y) % 64 == 0,
			"a moved building lands on the 64px grid (%s)" % moved)

	editor._handle_move_input(_click(viewport_pos, false))
	harness.check(editor._drag.is_empty(), "release closes the drag")
	harness.check(castle.position == moved, "the drag committed the dragged position")

	editor.undo()
	harness.check(castle.position == orig, "one undo restores the original building position")
	editor.redo()
	harness.check(castle.position == moved, "redo re-applies the moved position")
	editor.undo()  # leave the scaffold where we found it
	harness.check(castle.position == orig, "the scaffold is restored for the next test")


# ---------------------------------------------------------------------------
# Move tool: lane points
# ---------------------------------------------------------------------------

func _test_move_lane_point(harness, editor) -> void:
	var lane = editor.map_root.get_node_or_null("lanes/mid")
	harness.check(lane is Line2D, "the scaffold's mid lane is available")
	if not (lane is Line2D):
		return
	var count_before := (lane as Line2D).get_point_count()
	var canvas: Transform2D = editor.get_viewport().get_canvas_transform()
	var orig: Vector2 = (lane as Line2D).get_point_position(0)
	var viewport_pos: Vector2 = LaneLogic.viewport_to_node_xform(lane as CanvasItem, canvas) * orig

	ui_of(editor).move_mode_requested.emit(true)
	editor._handle_move_input(_click(viewport_pos, true))
	harness.check(editor._drag.get("kind") == "lane" and int(editor._drag.get("index", -2)) == 0,
			"a click on a lane point grabs that point")
	if editor._drag.get("kind") != "lane":
		editor._commit_pending()
		return
	harness.check(editor.lane_overlay.lane == lane,
			"the dragged lane shows in the overlay (the lanes node is hidden by design)")

	var pushed := viewport_pos + Vector2(192, -128)
	editor._handle_move_input(_motion(pushed))
	var moved: Vector2 = (lane as Line2D).get_point_position(0)
	harness.check(moved != orig, "dragging moves the lane point")
	harness.check(int(moved.x) % 64 == 0 and int(moved.y) % 64 == 0,
			"a moved lane point snaps to the 64px grid (%s)" % moved)
	harness.check((lane as Line2D).get_point_count() == count_before,
			"dragging a point never inserts or deletes points")

	editor._handle_move_input(_click(viewport_pos, false))
	harness.check(editor._drag.is_empty(), "release commits the lane-point drag")
	harness.check(editor.lane_overlay.lane == null,
			"the overlay goes back to neutral after the drag ends")

	editor.undo()
	harness.check((lane as Line2D).get_point_position(0) == orig,
			"one undo restores the original lane point")
	editor.redo()
	harness.check((lane as Line2D).get_point_position(0) == moved,
			"redo re-applies the moved lane point")
	editor.undo()  # scaffold state as found
	harness.check((lane as Line2D).get_point_position(0) == orig,
			"the lane is restored for the next test")


# A grab with no move leaves NO history entry, and empty ground does not grab.
func _test_move_wiring(harness, editor) -> void:
	var history_before: int = editor.undo_redo.get_history_count()
	# The top-left viewport corner is far from every lane point and building of
	# the fit-framed scaffold (the panel itself is not in play: handlers are
	# invoked directly, not through routed input).
	editor._handle_move_input(_click(Vector2.ZERO, true))
	harness.check(editor._drag.is_empty(), "a click on empty ground grabs nothing")
	editor._handle_move_input(_click(Vector2.ZERO, false))
	harness.check(editor.undo_redo.get_history_count() == history_before,
			"a no-motion grab commits no history entry")

	# The windowed crash (pull request feedback): press a GRABBABLE building,
	# release without any motion. Nothing may error, no history entry may
	# appear, the drag state must clear, and the building stays put.
	var castle2 = editor.map_root.get_node("buildings/blue/castle")
	var before: Vector2 = castle2.get("position")
	var vp2: Vector2 = LaneLogic.viewport_to_node_xform(castle2.get_parent(),
			editor.get_viewport().get_canvas_transform()) * before
	editor._handle_move_input(_click(vp2, true))
	harness.check(not editor._drag.is_empty(), "the crash-path press grabbed the building")
	editor._handle_move_input(_click(vp2, false))
	harness.check(editor._drag.is_empty(), "a press-release with no motion ends the drag cleanly")
	harness.check(editor.undo_redo.get_history_count() == history_before,
			"a press-release with no motion commits no history entry")
	harness.check(castle2.get("position") == before, "a no-motion grab leaves the building in place")

	# Tool toggles stay mutually exclusive, and Escape exits the mode.
	ui_of(editor).tile_mode_requested.emit(true)
	harness.check(ui_of(editor)._tile_toggle.button_pressed, "tiles toggle lit")
	ui_of(editor).move_mode_requested.emit(true)
	harness.check(editor.mode == "move" and not ui_of(editor)._tile_toggle.button_pressed,
			"entering move mode turns off the other tool toggles")
	editor._unhandled_input(_key(KEY_ESCAPE))
	harness.check(editor.mode == "" and not ui_of(editor)._move_toggle.button_pressed,
			"Escape exits move mode and turns the toggle off")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func ui_of(editor) -> Node:
	return editor.get_node("UILayer/EditorUI")


func _map_tile_px(map: Node) -> int:
	var raw = map.get("tile_size")
	if (raw is int or raw is float) and raw > 0:
		return int(raw)
	return 64


func _all_cells_empty(layer: TileMapLayer, cells: Array[Vector2i]) -> bool:
	for cell in cells:
		var twin := TileBrush.mirrored_cell(cell, TileBrush.cell_size_of(layer),
				TileBrush.mirror_size_for(layer))
		if layer.get_cell_source_id(cell) != -1:
			return false
		if twin != cell and layer.get_cell_source_id(twin) != -1:
			return false
	return true


func _click(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	return e


func _motion(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	return e


func _key(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.pressed = true
	return e
