extends RefCounted

# =============================================================================
# Lane drawing logic (addons/map_editor/lane_logic.gd)
# =============================================================================
# Pure, editor-free helpers for the plugin's lane-drawing mode. Everything
# that decides WHERE a click goes or WHICH lane is edited lives here so it
# can run in the headless unit suite (tests/unit/test_lane_logic.gd); the
# plugin only forwards editor input/output to these functions.
#
# Coordinate spaces:
#   - clicks from _forward_canvas_gui_input arrive in the 2D editor's
#     VIEWPORT (screen) space; the plugin converts them to lane-local
#     coordinates with viewport_to_node_xform() before calling these
#     helpers. Lane points are LOCAL to their Line2D.
#     Godot 4.7: the editor camera (pan/zoom) lives in the scene SubViewport's
#     global_canvas_transform (CanvasItemEditor pushes its transform there via
#     EditorNode::get_scene_root()->set_global_canvas_transform()), while the
#     plain canvas_transform stays IDENTITY — so
#     CanvasItem.get_global_transform_with_canvas() (canvas_transform *
#     global_transform) never sees pan/zoom. That was the "points land near
#     the origin / overlay glued to the window" bug. Viewport's
#     get_global_canvas_transform() IS ClassDB-exposed, so the plugin passes
#     it in and this helper stays editor-free and unit-testable.
#   - snap to base_map's tile grid so lanes line up with painted tiles.
# =============================================================================

const DEFAULT_GRID := 64


# The transform from node-local space to the editor viewport (screen) space:
# editor camera * node global transform. viewport_canvas_xform is the edited
# node's Viewport.get_global_canvas_transform() — the 2D editor's pan/zoom in
# Godot 4.7 (see the coordinate-spaces note above). Shared by the lane and
# building placement tools.
static func viewport_to_node_xform(node: CanvasItem, viewport_canvas_xform: Transform2D) -> Transform2D:
	return viewport_canvas_xform * node.get_global_transform()


# The lane a click should edit: the selected node if it is a Line2D under the
# map's lanes/ node, otherwise the first lane (the dock's "New lane" button
# creates one when lanes is empty).
static func target_lane(map_root: Node, selected_nodes: Array) -> Line2D:
	var lanes_node = map_root.get_node_or_null("lanes")
	if lanes_node == null:
		return null

	if selected_nodes != null:
		for selected in selected_nodes:
			if selected is Line2D and selected.get_parent() == lanes_node:
				return selected

	return _first_lane(lanes_node)


# First Line2D under the lanes node, or null.
static func _first_lane(lanes_node: Node) -> Line2D:
	for child in lanes_node.get_children():
		if child is Line2D:
			return child
	return null


# Nearest tile-grid intersection (rounds half away from zero).
static func snap_point(pos: Vector2, grid: int = DEFAULT_GRID) -> Vector2:
	return Vector2(roundf(pos.x / grid) * grid, roundf(pos.y / grid) * grid)


# Where a click at local_pos should insert into the lane: after the nearest
# segment's start point. Appends when there is no segment (fewer than 2
# points). Deterministic on ties (first/lowest index wins).
static func insertion_index(lane: Line2D, local_pos: Vector2) -> int:
	var count := lane.get_point_count()
	if count < 2:
		return count

	var best_index := 0
	var best_dist := INF
	for i in range(count - 1):
		var dist := _distance_to_segment(local_pos, lane.get_point_position(i), lane.get_point_position(i + 1))
		if dist < best_dist:
			best_dist = dist
			best_index = i + 1
	return best_index


static func _distance_to_segment(pos: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	if segment == Vector2.ZERO:
		return pos.distance_to(a)
	var t := clampf((pos - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return pos.distance_to(a + segment * t)


# First free "lane_N" name under the lanes node (lane_1, lane_2, ...).
static func next_lane_name(lanes_node: Node) -> String:
	var index := 1
	while lanes_node.get_node_or_null("lane_%d" % index) != null:
		index += 1
	return "lane_%d" % index
