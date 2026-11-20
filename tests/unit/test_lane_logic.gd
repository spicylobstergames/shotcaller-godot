extends RefCounted

# =============================================================================
# Lane drawing logic tests (tests/unit/test_lane_logic.gd)
# =============================================================================
# Covers addons/map_editor/lane_logic.gd — the editor-free core of the
# plugin's lane-drawing mode: target-lane resolution, grid snapping,
# insertion index by nearest segment, and lane naming. The interactive
# canvas input/overlay itself is editor-only and untestable headless.
# =============================================================================

const LaneLogic = preload("res://addons/map_editor/lane_logic.gd")
const Scaffold = preload("res://addons/map_editor/map_scaffold.gd")


func run(harness) -> void:
	_test_snap_point(harness)
	_test_target_lane(harness)
	_test_insertion_index(harness)
	_test_next_lane_name(harness)


# ---------------------------------------------------------------------------
# Snapping: clicks land on tile-grid intersections
# ---------------------------------------------------------------------------

func _test_snap_point(harness) -> void:
	harness.check_equal(LaneLogic.snap_point(Vector2(63, 70)), Vector2(64, 64),
			"near-miss coordinates snap to the nearest grid intersection")
	harness.check_equal(LaneLogic.snap_point(Vector2(31, 33)), Vector2(0, 64),
			"each axis snaps independently")
	harness.check_equal(LaneLogic.snap_point(Vector2(-30, -10)), Vector2(0, 0),
			"negative coordinates snap toward zero")
	harness.check_equal(LaneLogic.snap_point(Vector2(130, 50), 32), Vector2(128, 64),
			"grid size is parameterizable")
	harness.check_equal(LaneLogic.snap_point(Vector2(128, 192)), Vector2(128, 192),
			"on-grid points are unchanged")


# ---------------------------------------------------------------------------
# Target resolution: which lane does a click edit?
# ---------------------------------------------------------------------------

func _test_target_lane(harness) -> void:
	var map: Node = Scaffold.new().build_map()
	var lanes: Node = map.get_node("lanes")
	var mid: Line2D = lanes.get_node("mid")

	harness.check_equal(LaneLogic.target_lane(map, [mid]), mid,
			"a selected lane is the target")
	harness.check_equal(LaneLogic.target_lane(map, [map.get_node("buildings/blue/castle")]), mid,
			"selecting an unrelated node falls back to the first lane")
	harness.check_equal(LaneLogic.target_lane(map, []), mid,
			"no selection falls back to the first lane")

	lanes.remove_child(mid)
	mid.free()
	harness.check_equal(LaneLogic.target_lane(map, []), null,
			"no lanes means no target (dock's 'New lane' creates one)")

	map.free()


# ---------------------------------------------------------------------------
# Insertion index: clicks insert after the nearest segment
# ---------------------------------------------------------------------------

func _test_insertion_index(harness) -> void:
	var lane := Line2D.new()
	lane.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)])

	harness.check_equal(LaneLogic.insertion_index(lane, Vector2(50, -5)), 1,
			"click near the first segment inserts between its points")
	harness.check_equal(LaneLogic.insertion_index(lane, Vector2(250, 10)), 2,
			"click past the last segment inserts at its end")
	harness.check_equal(LaneLogic.insertion_index(lane, Vector2(-200, 0)), 1,
			"click before the start inserts into the nearest (first) segment")
	harness.check_equal(LaneLogic.insertion_index(Line2D.new(), Vector2(10, 10)), 0,
			"an empty lane appends at index 0")
	var single := Line2D.new()
	single.add_point(Vector2(5, 5))
	harness.check_equal(LaneLogic.insertion_index(single, Vector2(999, 999)), 1,
			"a single-point lane appends at index 1")

	lane.free()
	single.free()


# ---------------------------------------------------------------------------
# Lane naming: "New lane" never collides
# ---------------------------------------------------------------------------

func _test_next_lane_name(harness) -> void:
	var map: Node = Scaffold.new().build_map()
	var lanes: Node = map.get_node("lanes")

	harness.check_equal(LaneLogic.next_lane_name(lanes), "lane_1",
			"existing non-lane_N names do not collide with lane numbering")

	var first := Line2D.new()
	first.name = "lane_1"
	lanes.add_child(first)
	harness.check_equal(LaneLogic.next_lane_name(lanes), "lane_2",
			"lane_1 taken -> lane_2")

	var second := Line2D.new()
	second.name = "lane_2"
	lanes.add_child(second)
	# Free lane_1 the safe way: detach before freeing, or the parent keeps a
	# dangling child and the final map.free() crashes.
	lanes.remove_child(first)
	first.free()
	harness.check_equal(LaneLogic.next_lane_name(lanes), "lane_1",
			"freed names are reused")

	map.free()
