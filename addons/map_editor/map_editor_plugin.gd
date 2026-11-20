@tool
extends EditorPlugin

# Map editor plugin: registers the dock that scaffolds new map scenes and
# validates them against the runtime contract, plus the lane-drawing canvas
# mode. All decision logic lives in lane_logic.gd / map_scaffold.gd /
# map_validator.gd (headless-testable); this file only moves editor input.

const DockScript := preload("res://addons/map_editor/editor_dock.gd")
const LaneLogic := preload("res://addons/map_editor/lane_logic.gd")

var _dock: Control
var _lane_mode := false


func _enter_tree() -> void:
	# Without this, _forward_canvas_gui_input/_forward_canvas_draw_over_viewport
	# are not called for our plugin (input forwarding is opt-in per plugin),
	# so lane-drawing clicks are silently dropped. (Renamed from the 3.x
	# ..._always_relevant in Godot 4.)
	set_input_event_forwarding_always_enabled()
	_dock = DockScript.new()
	_dock.name = "Map Editor"
	_dock.lane_mode_requested.connect(_set_lane_mode)
	_dock.new_lane_requested.connect(_add_lane)
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null


# ---------------------------------------------------------------------------
# Lane drawing mode (Phase 2): left-click adds snapped points to the target
# lane, Escape (or the dock toggle) leaves the mode.
# ---------------------------------------------------------------------------

func _set_lane_mode(active: bool) -> void:
	if _lane_mode == active:
		return
	_lane_mode = active
	if _dock != null:
		_dock.set_lane_mode_active(active)  # keep the toggle in sync on Escape
	if active:
		var lane := LaneLogic.target_lane(_map_root(), _selected_nodes())
		if lane != null:
			_dock.log_line("Draw-lanes ON: left-click adds snapped points to '%s'; Escape exits." % lane.name)
		else:
			_dock.log_line("Draw-lanes ON, but there is no lane to edit — use 'New lane' first.")
	else:
		_dock.log_line("Draw-lanes OFF.")
	update_overlays()  # redraw the overlay when entering/leaving the mode


func _add_lane() -> void:
	var map_root := _map_root()
	if map_root == null:
		return
	var lanes_node = map_root.get_node_or_null("lanes")
	if lanes_node == null:
		push_warning("Map Editor: the open scene has no 'lanes' node.")
		return

	var lane := Line2D.new()
	lane.name = LaneLogic.next_lane_name(lanes_node)
	lane.default_color = Color(1, 1, 1, 0.196078)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Add lane")
	undo_redo.add_do_method(lanes_node, "add_child", lane)
	undo_redo.add_do_method(lane, "set_owner", map_root)
	undo_redo.add_do_reference(lane)
	undo_redo.add_undo_method(lanes_node, "remove_child", lane)
	undo_redo.add_undo_method(lane, "queue_free")
	undo_redo.commit_action()


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _lane_mode:
		return false

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_set_lane_mode(false)
		return true

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_add_lane_point(event.position)
		return true

	return false


func _add_lane_point(canvas_pos: Vector2) -> void:
	var map_root := _map_root()
	if map_root == null:
		return
	var lane := LaneLogic.target_lane(map_root, _selected_nodes())
	if lane == null:
		push_warning("Map Editor: no lane to draw on — select a lane or use 'New lane'.")
		return

	# Click positions arrive in canvas (world) space; Line2D points are local.
	var local := lane.to_local(LaneLogic.snap_point(canvas_pos))
	var index := LaneLogic.insertion_index(lane, local)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Add lane point")
	undo_redo.add_do_method(lane, "add_point", index, local)
	undo_redo.add_undo_method(lane, "remove_point", index)
	undo_redo.commit_action()
	if _dock != null:
		_dock.log_line("Added point %d at %s to '%s' (Ctrl+Z undoes)." % [index, local, lane.name])
	update_overlays()


func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	if not _lane_mode:
		return
	var map_root := _map_root()
	if map_root == null:
		return
	var lane := LaneLogic.target_lane(map_root, _selected_nodes())
	if lane == null:
		return

	# Show the user which lane is live and where its points are.
	var points := PackedVector2Array()
	for i in lane.get_point_count():
		points.append(_to_viewport(lane, lane.get_point_position(i)))
	if points.size() >= 2:
		viewport_control.draw_polyline(points, Color(0.3, 0.7, 1.0, 0.9), 2.0)
	for point in points:
		viewport_control.draw_circle(point, 4.0, Color(0.3, 0.7, 1.0, 1.0))


func _to_viewport(lane: Line2D, local_point: Vector2) -> Vector2:
	return EditorInterface.get_editor_viewport_2d().canvas_transform * lane.to_global(local_point)


func _map_root() -> Node:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or not (root is BaseMap):
		return null
	return root


func _selected_nodes() -> Array:
	var selection := EditorInterface.get_selection()
	if selection == null:
		return []
	return selection.get_selected_nodes()
