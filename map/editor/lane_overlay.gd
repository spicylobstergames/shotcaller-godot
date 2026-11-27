extends Node2D

# =============================================================================
# Lane overlay (map/editor/lane_overlay.gd)
# =============================================================================
# Highlights the lane the lane tool is editing — the runtime answer to the
# plugin's _forward_canvas_draw_over_viewport() overlay. It is a sibling of
# MapHolder (so it draws above the map) and deliberately NOT a child of the map
# (so it is never owned, never packed, never saved).
#
# The lanes node's own visibility is left exactly as authored (the scaffold
# hides it; the game needs that), which is why the editor needs this overlay at
# all: without it the lane being edited would be invisible.
# =============================================================================

const LINE_COLOR := Color(0.3, 0.7, 1.0, 0.9)
const POINT_COLOR := Color(0.3, 0.7, 1.0, 1.0)
const LINE_WIDTH := 2.0
const POINT_RADIUS := 4.0

# The lane being edited, set by map_editor.gd (_sync_overlay). Weak on purpose:
# undo can free the lane, so _draw re-checks validity instead of trusting it.
var lane: Line2D


func _draw() -> void:
	if lane == null or not is_instance_valid(lane):
		return
	var pts := PackedVector2Array()
	for i in lane.get_point_count():
		pts.append(to_local(lane.to_global(lane.get_point_position(i))))
	if pts.size() >= 2:
		draw_polyline(pts, LINE_COLOR, LINE_WIDTH, true)
	for p in pts:
		draw_circle(p, POINT_RADIUS, POINT_COLOR)
