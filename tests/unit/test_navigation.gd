extends RefCounted

# PORT (post-restructure): the use_native_pathfinding switch is gone —
# NavigateAction.find() now always delegates to the global Navigation
# autoload (path_grid + path_finder), so the backend-selector test is
# replaced by direct dispatch assertions against that seam.

const Pathfinder = preload("res://map/pathfind/jump_point_finder.gd")
const NavigateAction = preload("res://goap/game_logic/actions/navigate_action.gd")


class TestMap:
	extends Node2D
	var tile_size := 64
	var half_tile_size := 32
	var size := Vector2(320, 320)


func run(harness) -> void:
	# Use cloned grids because the pathfinder mutates node search state during each solve.
	var ws = preload("res://tests/helpers/world_state_snapshot.gd").new()
	ws.set_state("map", WorldState.get_state("map"))
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

	# --- NavigateAction dispatches to the global Navigation autoload ---
	var map = TestMap.new()
	harness.add_child(map)
	ws.set_state("map", map)
	var old_path_grid = Navigation.path_grid
	var old_path_finder = Navigation.path_finder
	Navigation.path_grid = Pathfinder.GridGD.new().Grid.new(5, 5)
	Navigation.path_finder = finder
	var navigate_action = NavigateAction.new()
	var found = navigate_action.find(Vector2(96, 96), Vector2(224, 224))
	harness.check(
		not found.is_empty(),
		"NavigateAction.find dispatches to the global Navigation pathfinder."
	)
	if not found.is_empty():
		# find() converts grid cells to world-space waypoints (half + cell *
		# tile_size) and SKIPS the source cell (range starts at 1): the first
		# waypoint is the next cell on the route.
		harness.check_equal(
			found.front(), Vector2(160, 160),
			"World-space paths start at the cell AFTER the source."
		)
		harness.check_equal(
			found.back(), Vector2(224, 224),
			"World-space paths end at the destination cell center."
		)

	# An unwalkable destination yields no path.
	Navigation.path_grid.setWalkableAt(3, 3, false)
	harness.check(
		navigate_action.find(Vector2(96, 96), Vector2(224, 224)).is_empty(),
		"NavigateAction.find returns no path to an unwalkable destination."
	)

	map.free()
	ws.restore()
	Navigation.path_grid = old_path_grid
	Navigation.path_finder = old_path_finder
