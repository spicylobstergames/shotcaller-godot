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
	_dock = DockScript.new()
	_dock.name = "Map Editor"
	_dock.lane_mode_requested.connect(_set_lane_mode)
	_dock.new_lane_requested.connect(_add_lane)
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


# Canvas input forwarding is gated on the plugin HANDLING the currently
# edited object (see EditorPlugin._handles docs): without _handles the editor
# never calls _forward_canvas_gui_input/_forward_canvas_draw_over_viewport
# and lane-drawing clicks are silently dropped. We handle any node that
# belongs to a BaseMap scene, so the mode survives selecting lanes/buildings
# while editing a map — and never fires in unrelated scenes.
func _handles(object: Object) -> bool:
	if not (object is Node):
		return false
	var node := object as Node
	if not node.is_inside_tree() or node.get_tree() == null:
		return false
	return node.get_tree().edited_scene_root is BaseMap


# Required companions of _handles; the lane tool keeps no per-object state.
func _edit(_object: Object) -> void:
	pass


func _make_visible(_visible: bool) -> void:
	pass


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
		# Make the editor treat the map root as the edited object right now, so
		# _handles/_forward_canvas_gui_input kick in even if the user has
		# nothing selected (or a non-map scene object was last edited).
		var map_root := _map_root()
		if map_root != null:
			EditorInterface.edit_node(map_root)
		var lane := LaneLogic.target_lane(map_root, _selected_nodes())
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


func _add_lane_point(viewport_pos: Vector2) -> void:
	var map_root := _map_root()
	if map_root == null:
		return
	var lane := LaneLogic.target_lane(map_root, _selected_nodes())
	if lane == null:
		push_warning("Map Editor: no lane to draw on — select a lane or use 'New lane'.")
		return

	# Clicks arrive in the 2D editor's VIEWPORT space. In Godot 4.7 the editor
	# camera (pan/zoom) is the scene SubViewport's global_canvas_transform
	# (CanvasItemEditor pushes its transform there via
	# EditorNode::get_scene_root()->set_global_canvas_transform()); the plain
	# canvas_transform stays identity, which is why the earlier
	# get_global_transform_with_canvas() attempt was near-identity too.
	# viewport_to_lane_xform() composes that camera with the lane's global
	# transform, so its inverse yields lane-local coordinates directly
	# (Line2D points are local) and always tracks pan/zoom.
	var xform := LaneLogic.viewport_to_lane_xform(
			lane, lane.get_viewport().get_global_canvas_transform())
	var local := LaneLogic.snap_point(xform.affine_inverse() * viewport_pos)
	var index := LaneLogic.insertion_index(lane, local)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Add lane point")
	undo_redo.add_do_method(lane, "add_point", local, index)
	undo_redo.add_undo_method(lane, "remove_point", index)
	undo_redo.commit_action()
	if _dock != null:
		_dock.log_line("Added point %d at %s to '%s' (clicked %s; lane xform origin %s)" % [
			index, local, lane.name, viewport_pos, xform.origin,
		])
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

	# Show the user which lane is live and where its points are. Same
	# viewport->lane transform as the input path (see _add_lane_point), so
	# overlay and clicks agree and the overlay tracks the world when
	# panning/zooming instead of gluing to the editor window.
	var xform := LaneLogic.viewport_to_lane_xform(
			lane, lane.get_viewport().get_global_canvas_transform())
	var points := PackedVector2Array()
	for i in lane.get_point_count():
		points.append(xform * lane.get_point_position(i))
	if points.size() >= 2:
		viewport_control.draw_polyline(points, Color(0.3, 0.7, 1.0, 0.9), 2.0)
	for point in points:
		viewport_control.draw_circle(point, 4.0, Color(0.3, 0.7, 1.0, 1.0))


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
