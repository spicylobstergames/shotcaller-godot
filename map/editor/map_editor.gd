extends Node2D

# =============================================================================
# Runtime map editor (map/editor/map_editor.gd)
# =============================================================================
# A scene, not an EditorPlugin: opened from the main menu, it authors maps with
# the dock's three authoring tools (lanes, buildings, tiles — tiles with an
# opt-out "Mirror paint" toggle, M5) plus a Move tool for repositioning
# already-placed buildings and lane points, and they share the dock's
# editor-free logic (lane_logic / building_logic / tile_brush_logic /
# map_scaffold / map_validator, all RefCounted). What the dock gets from the
# editor — UndoRedo, a canvas, a selection, click→world math — is rebuilt here:
# undo_redo := UndoRedo.new(), its own Camera2D, an explicit "current tool mode"
# instead of EditorInterface selection, and get_viewport().get_canvas_transform()
# instead of the editor-only get_global_canvas_transform() (identity at runtime).
#
# Godot 4.7 note: UndoRedo (the runtime class) takes a Callable —
# add_do_method(node.method.bind(args)) — the (object, "method", args) form the
# plugin uses belongs to EditorUndoRedoManager and is editor-only. The runtime
# editor therefore binds every do/undo action.
#
# Maps are saved through map_store.gd into user://maps/ and Play boots one as
# player blue vs enemy red via WorldState's "pending_map" handoff.
# =============================================================================

const Scaffold = preload("res://addons/map_editor/map_scaffold.gd")
const Validator = preload("res://addons/map_editor/map_validator.gd")
const LaneLogic = preload("res://addons/map_editor/lane_logic.gd")
const BuildingLogic = preload("res://addons/map_editor/building_logic.gd")
const TileBrush = preload("res://addons/map_editor/tile_brush_logic.gd")
const MapStore = preload("res://map/editor/map_store.gd")
const EditorUI = preload("res://map/editor/editor_ui.gd")
const LaneOverlay = preload("res://map/editor/lane_overlay.gd")

const GAME_SCENE := "res://game.tscn"
const DEFAULT_LANE_COLOR := Color(1, 1, 1, 0.196078)
const FALLBACK_MAP_SIZE := Vector2(1056, 1056)
# How close a Move-tool click must land on a lane point or building, in
# VIEWPORT pixels so the pick radius stays stable at any zoom level.
const MOVE_PICK_RADIUS := 48.0

# Typed on purpose: the tool getters (ui.selected_tile(), lane_overlay.lane) are
# checked against their scripts at parse time instead of failing at runtime.
@onready var camera: Camera2D = $EditorCamera
@onready var map_holder: Node2D = $MapHolder
@onready var lane_overlay: LaneOverlay = $LaneOverlay
@onready var ui: EditorUI = $UILayer/EditorUI

var map_root: Node2D = null
var undo_redo := UndoRedo.new()
var mode := ""  # "", "lane", "building", "tile", "move"
var _stroke: Dictionary = {}  # {"layer": TileMapLayer, "erase": bool, "undo": {}}
# The active drag of the Move tool: {"kind": "lane"|"building", "node",
# "index": int (lane points), "orig": Vector2 (the node-local start position)}.
# One drag is exactly one undo action; no motion = no history entry.
var _drag: Dictionary = {}

# Editor-only visibility bookkeeping: hidden flags are serialized into the
# .tscn, so anything the editor hides must be remembered and put back before
# packing (see _hide_for_editing / _restore_for_save).
var _editor_hidden: Array = []  # [{"node": Node, "visible": bool}]


func _ready() -> void:
	_connect_ui()
	camera.make_current()
	ui.set_map_root(null)
	ui.log_line("New map or Open a saved map.")


func _connect_ui() -> void:
	ui.new_map_requested.connect(_on_new_map)
	ui.open_map_requested.connect(_on_open_map)
	ui.save_map_requested.connect(_on_save_map)
	ui.delete_map_requested.connect(_on_delete_map)
	ui.validate_requested.connect(_on_validate)
	ui.play_requested.connect(_on_play)
	ui.exit_requested.connect(_on_exit)
	ui.lane_mode_requested.connect(func(active: bool) -> void: _set_mode("lane" if active else ""))
	ui.building_mode_requested.connect(func(active: bool) -> void: _set_mode("building" if active else ""))
	ui.tile_mode_requested.connect(func(active: bool) -> void: _set_mode("tile" if active else ""))
	ui.move_mode_requested.connect(func(active: bool) -> void: _set_mode("move" if active else ""))
	ui.new_lane_requested.connect(_on_new_lane)
	ui.lane_selected.connect(_sync_overlay)
	ui.undo_requested.connect(undo)
	ui.redo_requested.connect(redo)


# ---------------------------------------------------------------------------
# Map install / replace
# ---------------------------------------------------------------------------

# One map at a time: the editor edits what map_root points at, and installing a
# new one drops the old one (unsaved edits go with it).
func _install_map(map: Node2D, display_name := "untitled") -> void:
	if map == null:
		return
	_commit_pending()
	_set_mode("")

	var old := map_root
	if old != null and is_instance_valid(old):
		map_holder.remove_child(old)
		old.queue_free()

	map_holder.add_child(map)
	map_root = map
	# Owner assignment before painting: TileBrush.mirror_size_for() reads
	# layer.get_owner() as BaseMap, and save-time packing serializes only owned
	# nodes. (A loaded .tscn already owns its subtree; a fresh scaffold does not.)
	MapStore.own_tree(map, map)
	_hide_for_editing(map)
	undo_redo.clear_history()

	lane_overlay.lane = null
	ui.set_map_root(map)
	ui.set_map_name(display_name)
	ui.refresh_lanes()
	ui.refresh_map_list()
	camera.frame_map(_map_size(map), get_viewport_rect().size)

	ui.log_line("Editing %s" % display_name)
	lane_overlay.queue_redraw()


func _map_size(map: Node) -> Vector2:
	var raw = map.get("size")
	return raw if raw is Vector2 else FALLBACK_MAP_SIZE


# BaseMap.tile_size (the map-tile grid the gameplay systems use), with the
# dock's 64px fallback for a map root that has no such export.
func _map_tile_px() -> int:
	if map_root == null:
		return 64
	var raw = map_root.get("tile_size")
	if (raw is int or raw is float) and raw > 0:
		return int(raw)
	return 64


# ---------------------------------------------------------------------------
# Editor-only visibility (fog is black-at-rest, HUD labels are runtime chrome,
# zoom_out_sprite is the minimap's render target)
# ---------------------------------------------------------------------------

func _hide_node(node: Node) -> void:
	if node == null:
		return
	_editor_hidden.append({"node": node, "visible": node.visible})
	node.hide()


func _hide_for_editing(map: Node) -> void:
	_editor_hidden.clear()
	_hide_node(map.get_node_or_null("fog"))
	_hide_node(map.get_node_or_null("zoom_out_sprite"))
	var buildings := map.get_node_or_null("buildings")
	if buildings == null:
		return
	for team in buildings.get_children():
		for building in team.get_children():
			_hide_node(building.get_node_or_null("hud"))


func _restore_for_save() -> void:
	for entry in _editor_hidden:
		# Untyped on purpose: an entry's node can be FREED while hidden (a
		# building undone away after its hud was recorded). A typed read would
		# raise "Trying to assign invalid previously freed instance" and abort
		# the loop on the first stale entry, leaving LATER entries' hidden flags
		# active for the pack — the leak this restore exists to prevent.
		var node = entry["node"]
		if node != null and is_instance_valid(node):
			node.visible = entry["visible"]
	_editor_hidden.clear()


func _hide_again_after_save() -> void:
	_hide_for_editing(map_root)


# ---------------------------------------------------------------------------
# File and session requests
# ---------------------------------------------------------------------------

func _on_new_map() -> void:
	_install_map(Scaffold.new().build_map(), "untitled")


func _on_open_map(map_name: String) -> void:
	if map_name == "":
		ui.log_line("REFUSED: select a saved map first.")
		return
	var map = MapStore.load_map(map_name)
	if map == null or not (map is Node2D):
		ui.log_line("REFUSED: could not open user://maps/%s.tscn." % MapStore.sanitize_name(map_name))
		return
	_install_map(map, map_name)


func _on_save_map() -> void:
	if map_root == null:
		ui.log_line("REFUSED: nothing to save. New map first.")
		return
	_commit_pending()
	var err := _save_current_map()
	if err == OK:
		ui.log_line("Saved %s (%s)" % [MapStore.path_for(ui.map_name()),
				ProjectSettings.globalize_path(MapStore.path_for(ui.map_name()))])
	else:
		ui.log_line("SAVE FAILED: %s (%s)" % [error_string(err), MapStore.path_for(ui.map_name())])
	# Validation reports the saved map's problems but never undoes the save.
	_log_problems(Validator.new().validate(map_root))
	ui.refresh_map_list()
	ui.set_map_name(MapStore.sanitize_name(ui.map_name()))


func _on_delete_map(map_name: String) -> void:
	# Same guard as Open: with nothing selected the store would sanitize "" into
	# its fallback name and delete whoever happens to be saved as "map".
	if map_name == "":
		ui.log_line("REFUSED: select a saved map to delete.")
		return
	var err := MapStore.delete_map(map_name)
	if err == OK:
		ui.log_line("Deleted %s" % MapStore.path_for(map_name))
	elif err == ERR_FILE_NOT_FOUND:
		ui.log_line("REFUSED: no saved map named '%s'." % MapStore.sanitize_name(map_name))
	else:
		ui.log_line("DELETE FAILED: %s" % error_string(err))
	ui.refresh_map_list()


func _on_validate() -> void:
	if map_root == null:
		ui.log_line("REFUSED: nothing to validate. New map first.")
		return
	_commit_pending()
	var problems: Array = Validator.new().validate(map_root)
	if problems.is_empty():
		ui.log_line("Validation: no problems.")
		return
	_log_problems(problems)


func _on_exit() -> void:
	_commit_pending()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_play() -> void:
	if map_root == null:
		ui.log_line("REFUSED: nothing to play. New map first.")
		return
	_commit_pending()
	var problems: Array = Validator.new().validate(map_root)
	_log_problems(problems)
	for problem in problems:
		if problem.get("level", "") == "error":
			ui.log_line("PLAY REFUSED: fix the validation errors above first.")
			return
	var err := _save_current_map()
	if err != OK:
		ui.log_line("PLAY REFUSED: save failed (%s)." % error_string(err))
		return
	# The handoff: game.gd's _ready sees pending_map and boots this map as
	# blue vs red instead of showing the main menu.
	WorldState.set_state("pending_map", MapStore.path_for(ui.map_name()))
	ui.log_line("Playing %s as blue vs red." % MapStore.path_for(ui.map_name()))
	get_tree().change_scene_to_file(GAME_SCENE)


# The visibility-safe save path (restore hidden chrome, pack, hide it again) so
# a saved map never carries the editor's hidden flags into the .tscn.
func _save_current_map() -> int:
	_restore_for_save()
	var err := MapStore.save_map(map_root, ui.map_name())
	_hide_again_after_save()
	return err


func _log_problems(problems: Array) -> void:
	for level in ["error", "warning"]:
		for problem in problems:
			if problem.get("level", "") == level:
				ui.log_line("%s: %s" % [level.to_upper(), problem.get("message", "")])


# ---------------------------------------------------------------------------
# Input: camera first (it never competes with the tools), then shortcuts, then
# the active tool. _unhandled_input because the UI Controls must get first
# refusal on their own clicks.
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if camera.handle_input(event):
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and mode != "":
			_set_mode("")
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_Z:
			undo()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_Y:
			redo()
			get_viewport().set_input_as_handled()
			return

	if mode == "" or map_root == null:
		return
	if mode == "lane":
		_handle_lane_input(event)
	elif mode == "building":
		_handle_building_input(event)
	elif mode == "tile":
		_handle_tile_input(event)
	elif mode == "move":
		_handle_move_input(event)


func _set_mode(new_mode: String) -> void:
	if new_mode == mode:
		return
	_commit_pending()
	var previous := mode
	mode = new_mode
	if previous != "":
		ui.set_mode_active(previous, false)
	if mode != "":
		ui.set_mode_active(mode, true)
	if mode == "tile":
		ui.refresh_tile_picker()
	# The overlay only mirrors the lane tool; entering lane mode makes it follow
	# the dropdown at once, leaving it hides it again.
	_sync_overlay(ui.selected_lane_name())


func undo() -> void:
	_commit_pending()
	undo_redo.undo()
	_refresh_after_change()


func redo() -> void:
	_commit_pending()
	undo_redo.redo()
	_refresh_after_change()


func _refresh_after_change() -> void:
	ui.refresh_lanes()
	ui.refresh_tile_picker()
	_sync_overlay(ui.selected_lane_name())


func _sync_overlay(lane_name: String) -> void:
	var lane: Line2D = null
	if mode == "lane" and map_root != null and lane_name != "":
		var found = map_root.get_node_or_null("lanes/" + lane_name)
		if found is Line2D:
			lane = found
	lane_overlay.lane = lane
	lane_overlay.queue_redraw()


# Viewport click -> node-local point, via the RUNTIME canvas transform (the
# editor's get_global_canvas_transform() is identity here). Callers pass a
# CanvasItem (a lane or a buildings/<team> node); place_target is typed Node.
func _local_point(node: Node, viewport_pos: Vector2) -> Vector2:
	var item := node as CanvasItem
	if item == null:
		return LaneLogic.snap_point(viewport_pos)
	var canvas := get_viewport().get_canvas_transform()
	return LaneLogic.snap_point(LaneLogic.viewport_to_node_xform(item, canvas).affine_inverse() * viewport_pos)


# ---------------------------------------------------------------------------
# Lane tool
# ---------------------------------------------------------------------------

func _handle_lane_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var lane := _selected_lane()
	if lane == null:
		return
	var local := _local_point(lane, click.position)
	var index := LaneLogic.insertion_index(lane, local)
	undo_redo.create_action("Add lane point")
	undo_redo.add_do_method(lane.add_point.bind(local, index))
	undo_redo.add_undo_method(lane.remove_point.bind(index))
	undo_redo.commit_action()
	lane_overlay.queue_redraw()
	get_viewport().set_input_as_handled()


func _selected_lane() -> Line2D:
	var lane_name := ui.selected_lane_name()
	if lane_name == "":
		ui.log_line("REFUSED: no lane selected. New lane first.")
		return null
	var found = map_root.get_node_or_null("lanes/" + lane_name)
	if not (found is Line2D):
		ui.log_line("REFUSED: lane '%s' is not in this map." % lane_name)
		return null
	return found


func _on_new_lane() -> void:
	if map_root == null:
		ui.log_line("REFUSED: create a map first.")
		return
	var lanes_node := map_root.get_node_or_null("lanes")
	if lanes_node == null:
		ui.log_line("REFUSED: this map has no lanes node.")
		return
	var lane := Line2D.new()
	# Named before add_child so Node's sibling-name dedup does not mint
	# "mid6"/"lane2" behind the validator's back.
	lane.name = LaneLogic.next_lane_name(lanes_node)
	lane.default_color = DEFAULT_LANE_COLOR
	undo_redo.create_action("New lane")
	undo_redo.add_do_method(lanes_node.add_child.bind(lane))
	undo_redo.add_do_method(lane.set_owner.bind(map_root))
	undo_redo.add_do_reference(lane)
	undo_redo.add_undo_method(lanes_node.remove_child.bind(lane))
	undo_redo.add_undo_method(lane.queue_free)
	undo_redo.commit_action()
	ui.refresh_lanes()
	ui.select_lane(lane.name)
	_sync_overlay(lane.name)
	ui.log_line("Created lane '%s'." % lane.name)


# ---------------------------------------------------------------------------
# Building tool
# ---------------------------------------------------------------------------

func _handle_building_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	_place_building(click.position)
	get_viewport().set_input_as_handled()


func _place_building(viewport_pos: Vector2) -> void:
	var scene_path := ui.selected_building_scene()
	if scene_path == "":
		ui.log_line("REFUSED: no building scene selected.")
		return
	var team := ui.selected_team()
	var base_name := BuildingLogic.building_base_name(scene_path)
	# parent_team is the DIRECTORY to place into; team is the METADATA team.
	# They differ for neutrals, which live in whichever team directory exists.
	var parent_team := team
	if team == "neutral":
		parent_team = BuildingLogic.neutral_host_team(map_root)
		if parent_team == "":
			ui.log_line("REFUSED: neutral buildings need a buildings/blue or buildings/red directory.")
			return
	if not BuildingLogic.is_placement_allowed(base_name, team):
		ui.log_line("REFUSED: %s is a team structure and cannot be placed as neutral." % base_name)
		return
	var team_node := BuildingLogic.place_target(map_root, parent_team)
	if team_node == null:
		ui.log_line("REFUSED: this map has no buildings/%s directory." % parent_team)
		return
	var lane_name := ui.selected_lane_name()
	if lane_name == "":
		ui.log_line("REFUSED: select a lane first (its name is the building's subtype).")
		return
	var scene = load(scene_path)
	if not (scene is PackedScene):
		ui.log_line("REFUSED: %s is not a loadable scene." % scene_path)
		return
	var building: Node = (scene as PackedScene).instantiate()
	if building == null:
		ui.log_line("REFUSED: %s could not be instantiated." % scene_path)
		return

	# Metadata BEFORE add_child (sibling-name dedup) and keyed on the KIND,
	# never on the minted node name.
	building.name = BuildingLogic.next_building_name(team_node, base_name)
	building.position = _local_point(team_node, viewport_pos)
	BuildingLogic.apply_building_meta(building, base_name, team, lane_name)
	var applied_team = building.get("team")
	BuildingLogic.apply_editor_team_visuals(building, applied_team if applied_team is String else team)

	undo_redo.create_action("Place building")
	undo_redo.add_do_method(team_node.add_child.bind(building))
	undo_redo.add_do_method(building.set_owner.bind(map_root))
	undo_redo.add_do_reference(building)
	undo_redo.add_undo_method(team_node.remove_child.bind(building))
	undo_redo.add_undo_method(building.queue_free)
	undo_redo.commit_action()
	# Consistent with _hide_for_editing so save-time restore finds it.
	_hide_node(building.get_node_or_null("hud"))

	ui.log_line("Placed %s as %s at %s -> buildings/%s/%s (subtype %s)" % [
		base_name, team, building.position, parent_team, building.name, lane_name])


# ---------------------------------------------------------------------------
# Tile tool (one undo action per press-drag-release stroke)
# ---------------------------------------------------------------------------

func _handle_tile_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_paint_at(click.position, false)
			else:
				_commit_pending()
			get_viewport().set_input_as_handled()
			return
		if click.button_index == MOUSE_BUTTON_RIGHT:
			if click.pressed:
				_paint_at(click.position, true)
			else:
				_commit_pending()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion:
		if _stroke.is_empty():
			return
		var erase: bool = _stroke.get("erase", false)
		var held := MOUSE_BUTTON_MASK_RIGHT if erase else MOUSE_BUTTON_MASK_LEFT
		if not (event.button_mask & held):
			# The release was eaten by the UI panel: end the stroke rather than
			# paint on every later mouse move.
			_commit_pending()
			return
		_paint_at(event.position, erase)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Move tool (drag buildings and lane points; one undo action per drag)
# ---------------------------------------------------------------------------

func _handle_move_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_grab_move_target(click.position)
			else:
				_commit_pending()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion:
		if _drag.is_empty():
			return
		# Same guard as tile strokes: if the release was eaten by the UI panel,
		# end the drag instead of moving on every later mouse move.
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_commit_pending()
			return
		_drag_move(event.position)
		get_viewport().set_input_as_handled()


# Grab the NEAREST draggable thing under the cursor, in viewport pixels: any
# lane point under lanes/, or any building under buildings/<team>/ (the
# scaffold's pre-placed castle/barracks included). Position-only: names, team
# metadata, subtypes and point counts never change; re-parenting is out of
# scope (M5 fixed decision 3).
func _grab_move_target(viewport_pos: Vector2) -> void:
	var best: Dictionary = {}
	_lanes_pick(viewport_pos, best)
	_buildings_pick(viewport_pos, best)
	if best.is_empty() or best.get("distance", INF) > MOVE_PICK_RADIUS:
		return
	# Undo side first (the original position); the do side is queued at commit,
	# so intermediate drag positions never enter history.
	var orig: Vector2 = best.get("orig")
	if best.get("kind") == "lane":
		var lane := best.get("node") as Line2D
		undo_redo.create_action("Move lane point")
		undo_redo.add_undo_method(lane.set_point_position.bind(int(best.get("index")), orig))
		# The scaffold hides the lanes node by design; while a lane point is
		# dragged the overlay shows that lane so the author sees the thing
		# they are dragging (the lane mode's own overlay rules are untouched).
		lane_overlay.lane = lane
		lane_overlay.queue_redraw()
	else:
		var building := best.get("node") as Node2D
		undo_redo.create_action("Move building")
		undo_redo.add_undo_method(building.set_position.bind(orig))
	ui.log_line("Grabbed %s (drag to move; release to commit)." % _node_label(
			best.get("node"), int(best.get("index", -1))))
	_drag = best


# Nearest lane point within reach: lane-local points projected through the
# runtime canvas transform, compared in viewport space on purpose so zoom
# cannot change which thing is nearest.
func _lanes_pick(viewport_pos: Vector2, best: Dictionary) -> void:
	var lanes_node := map_root.get_node_or_null("lanes")
	if lanes_node == null:
		return
	for lane in lanes_node.get_children():
		if not (lane is Line2D):
			continue
		var xform := LaneLogic.viewport_to_node_xform(lane, get_viewport().get_canvas_transform())
		for i in (lane as Line2D).get_point_count():
			var point_viewport: Vector2 = xform * (lane as Line2D).get_point_position(i)
			var distance := point_viewport.distance_to(viewport_pos)
			if distance < best.get("distance", INF):
				best["kind"] = "lane"
				best["node"] = lane
				best["index"] = i
				best["orig"] = (lane as Line2D).get_point_position(i)
				best["distance"] = distance


# Nearest building under buildings/<team>; its position is team-node-local.
func _buildings_pick(viewport_pos: Vector2, best: Dictionary) -> void:
	var buildings_node := map_root.get_node_or_null("buildings")
	if buildings_node == null:
		return
	for team in buildings_node.get_children():
		var team_item := team as CanvasItem
		if team_item == null:
			continue
		var xform := LaneLogic.viewport_to_node_xform(team_item, get_viewport().get_canvas_transform())
		for building in team.get_children():
			var distance := (xform * (building as Node2D).position).distance_to(viewport_pos)
			if distance < best.get("distance", INF):
				best["kind"] = "building"
				best["node"] = building
				best["index"] = -1
				best["orig"] = (building as Node2D).position
				best["distance"] = distance


# Live drag: viewport click -> node-local point, snapped to the 64px grid
# (placement snaps the same way, so a moved thing lands where a fresh one
# would have).
func _drag_move(viewport_pos: Vector2) -> void:
	var node = _drag.get("node")
	if node == null or not is_instance_valid(node):
		_commit_pending()
		return
	var canvas := get_viewport().get_canvas_transform()
	if _drag.get("kind") == "lane":
		var lane := node as Line2D
		var local := LaneLogic.snap_point(
				LaneLogic.viewport_to_node_xform(lane, canvas).affine_inverse() * viewport_pos)
		lane.set_point_position(int(_drag.get("index", -1)), local)
		lane_overlay.queue_redraw()
	else:
		var team = node.get_parent()
		var local := LaneLogic.snap_point(
				LaneLogic.viewport_to_node_xform(team as CanvasItem, canvas).affine_inverse() * viewport_pos)
		(node as Node2D).set("position", local)


func _paint_at(viewport_pos: Vector2, erase: bool) -> void:
	var brush := ui.selected_brush()
	var layer := TileBrush.layer_for_brush(map_root, brush)
	if layer == null:
		ui.log_line("REFUSED: no TileMapLayer for brush '%s'." % brush)
		return
	# The brush dropdown is live: it can change while a button is held. Close the
	# stroke so the new layer gets its own undo action and its own walls guard
	# instead of silently bypassing both mid-drag.
	if not _stroke.is_empty() and layer != _stroke.get("layer"):
		_commit_pending()
	var cell_size := TileBrush.cell_size_of(layer)
	if cell_size == Vector2i.ZERO:
		ui.log_line("REFUSED: the '%s' TileSet has no cell size." % brush)
		return
	# Erase needs no tile; painting does. Checked before the stroke opens so a
	# misconfigured picker never leaves an empty undo action hanging.
	var tile: Dictionary = {} if erase else ui.selected_tile()
	if not erase and tile.is_empty():
		ui.log_line("No tile selected.")
		return

	if _stroke.is_empty():
		if brush == "walls":
			var guard := TileBrush.walls_guard_message(map_root, brush, layer)
			if guard != "":
				ui.log_line(guard)
				return
		undo_redo.create_action("Erase tiles" if erase else "Paint tiles")
		_stroke = {"layer": layer, "erase": erase, "undo": {}}

	var canvas := get_viewport().get_canvas_transform()
	var local := TileBrush.viewport_to_local(layer, viewport_pos, canvas)
	var cells: Array[Vector2i]
	if ui.selected_block_is_full_tile():
		cells = TileBrush.paint_cells_for_local(layer, local, _map_tile_px())
	else:
		cells = TileBrush.block_cells(TileBrush.viewport_to_cell(layer, viewport_pos, canvas),
				ui.selected_block_cells())

	var source_id: int = -1 if erase else int(tile.get("source_id", -1))
	var atlas: Vector2i = Vector2i(-1, -1) if erase else tile.get("atlas_coords", Vector2i(-1, -1))
	var mirror_size := TileBrush.mirror_size_for(layer)
	# The twin write is OPT-IN per stroke (M5): read live from the "Mirror
	# paint" toggle so an author can turn the scaffold's symmetric mirroring
	# off and paint only where clicked. Default on preserves the M3 contract.
	var mirroring := ui.mirror_enabled()
	var recorded: Dictionary = _stroke.get("undo", {})
	for coords in cells:
		_paint_cell_in_stroke(layer, coords, recorded, erase, source_id, atlas)
		if mirroring:
			var mirrored := TileBrush.mirrored_cell(coords, cell_size, mirror_size)
			if mirrored != coords:
				_paint_cell_in_stroke(layer, mirrored, recorded, erase, source_id, atlas)


# Record the cell's pre-stroke state once, queue its do/undo methods into the
# stroke's action, and apply it immediately so the canvas updates live. The undo
# methods must be real TileMapLayer methods — TileBrush.restore_cell_state is a
# static helper on a different object, which is an invalid Callable and made
# every undo error (the M3 bug).
func _paint_cell_in_stroke(layer: TileMapLayer, coords: Vector2i, recorded: Dictionary,
		erase: bool, source_id: int, atlas: Vector2i) -> void:
	var key := "%d:%d" % [coords.x, coords.y]
	if recorded.has(key):
		return  # already handled this stroke; keep its recorded pre-state
	var state: Dictionary = TileBrush.get_cell_state(layer, coords)
	recorded[key] = state
	if erase:
		undo_redo.add_do_method(layer.erase_cell.bind(coords))
	else:
		undo_redo.add_do_method(layer.set_cell.bind(coords, source_id, atlas, 0))
	if state.get("present", false):
		undo_redo.add_undo_method(layer.set_cell.bind(coords, state.get("source_id", -1),
				state.get("atlas_coords", Vector2i(-1, -1)), state.get("alternative_tile", 0)))
	else:
		undo_redo.add_undo_method(layer.erase_cell.bind(coords))
	if erase:
		layer.erase_cell(coords)
	else:
		layer.set_cell(coords, source_id, atlas, 0)


# Close ALL pending tool work — a move drag and a tile stroke — at the same
# lifecycle points: release, Escape, mode switch, map install, save, validate,
# play, exit, Undo/Redo. Safe to call when nothing is open.
func _commit_pending() -> void:
	_commit_drag()
	_commit_stroke()


# Close the active Move-tool drag as one undo action. The undo side (the
# original position) was queued at grab; the do side (the final position) is
# queued here so intermediates never enter history. A grab without motion
# equivalent to the original cancels instead of recording a no-op.
func _commit_drag() -> void:
	if _drag.is_empty():
		return
	var node = _drag.get("node")
	var final := Vector2.ZERO
	var valid := false
	if node != null and is_instance_valid(node):
		valid = true
		if _drag.get("kind") == "lane":
			final = (node as Line2D).get_point_position(int(_drag.get("index", -1)))
		else:
			final = (node as Node2D).position
	if not valid:
		undo_redo.cancel_action()
		_drag = {}
		return
	var orig: Vector2 = _drag.get("orig", final)
	if final != orig:
		if _drag.get("kind") == "lane":
			undo_redo.add_do_method((node as Line2D).set_point_position.bind(int(_drag.get("index", -1)), final))
		else:
			undo_redo.add_do_method((node as Node2D).set_position.bind(final))
		undo_redo.commit_action()
		ui.log_line("Moved %s: %s -> %s" % [
				_node_label(node, int(_drag.get("index", -1))), orig, final])
	else:
		# Left the click on the spot: no history entry for doing nothing.
		undo_redo.cancel_action()
	if _drag.get("kind") == "lane" and mode != "lane":
		lane_overlay.lane = null  # the drag preview goes with the drag
		lane_overlay.queue_redraw()
	_drag = {}


# "lanes/mid[2]" / "buildings/blue/tower_2" — for the log and nothing else.
func _node_label(node: Node, point_index: int) -> String:
	var label := "%s/%s" % [node.get_parent().name, node.name]
	if point_index >= 0:
		label += "[%d]" % point_index
	return label


# Close the active tile stroke. Safe to call with no stroke open.
func _commit_stroke() -> void:
	if _stroke.is_empty():
		return
	# A stroke that never wrote a cell (a click that landed on nothing
	# paintable) has no do/undo methods; committing an empty action errors.
	if (_stroke.get("undo", {}) as Dictionary).is_empty():
		undo_redo.cancel_action()
	else:
		undo_redo.commit_action()
	_stroke = {}
