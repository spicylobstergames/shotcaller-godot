extends RefCounted

const Pathfinder = preload("res://map/pathfind/jump_point_finder.gd")
const NavigateAction = preload("res://goap/game_logic/actions/navigate_action.gd")


class TestMap:
	extends Node2D
	var tile_size := 64
	var half_tile_size := 32
	var size := Vector2(320, 320)


func run(harness) -> void:
	# Use cloned grids because the pathfinder mutates node search state during each solve.
	var old_map = WorldState.get_state("map")
	var old_native_pathfinding = Goap.use_native_pathfinding
	var grid = Pathfinder.GridGD.new().Grid.new(5, 5)
	var finder = Pathfinder.JumpPointFinder.new()
	var open_path = finder.findPath(0, 0, 4, 4, grid.clone())
	harness.check(not open_path.is_empty(), "Pathfinder finds a route across open terrain.")
	if not open_path.is_empty():
		harness.check_equal(open_path.front(), [0, 0], "Open routes start at the source.")
		harness.check_equal(open_path.back(), [4, 4], "Open routes end at the destination.")

	for y in range(4):
		grid.setWalkableAt(2, y, false)
	# A single opening at the bottom should force the route around the wall.
	var route_around_wall = finder.findPath(0, 0, 4, 0, grid.clone())
	harness.check(
		not route_around_wall.is_empty(), "Pathfinder routes around a wall with an open passage."
	)
	if not route_around_wall.is_empty():
		harness.check(
			route_around_wall.any(func(point): return point[1] == 4),
			"Wall detours pass through the only open row."
		)

	grid.setWalkableAt(2, 4, false)
	var blocked_path = finder.findPath(0, 0, 4, 0, grid.clone())
	harness.check(blocked_path.is_empty(), "Pathfinder rejects a fully sealed wall.")

	var map = TestMap.new()
	harness.add_child(map)
	WorldState.set_state("map", map)
	# Exercise the public backend selector: custom search works, while the empty native map
	# correctly produces no route.
	var navigate_action = NavigateAction.new()
	navigate_action.path_grid = Pathfinder.GridGD.new().Grid.new(5, 5)
	navigate_action.path_finder = finder
	Goap.use_native_pathfinding = false
	harness.check(
		not navigate_action.find(Vector2(96, 96), Vector2(224, 224)).is_empty(),
		"Legacy navigation switch dispatches to the custom pathfinder."
	)
	Goap.use_native_pathfinding = true
	harness.check(
		navigate_action.find(Vector2(96, 96), Vector2(224, 224)).is_empty(),
		"Native navigation switch dispatches to Godot's navigation map."
	)
	map.free()
	WorldState.set_state("map", old_map)
	Goap.use_native_pathfinding = old_native_pathfinding
