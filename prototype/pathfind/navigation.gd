extends Node

const Finder = preload("jump_point_finder.gd")

var path_grid
var path_finder
var path_line


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func setup_pathfind():
	var map = WorldState.get_state("map")
	var grid_width = int(floor(map.size.x / map.tile_size)) + 1
	var grid_height = int(floor(map.size.y / map.tile_size)) + 1
	var grid = Finder.GridGD.new().Grid
	path_grid = grid.new(grid_width, grid_height)
	var walls_tile = map.walls
	for cell in walls_tile.get_used_cells():
		var team = "blue" if walls_tile.get_cell_source_id(cell) == 0 else "red"
		Collisions.create_block(cell.x, cell.y, team)
		path_grid.setWalkableAt(cell.x, cell.y, false)
	for building in WorldState.get_state("player_buildings"):
		var pos = (building.global_position / map.tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	for building in WorldState.get_state("enemy_buildings"):
		var pos = (building.global_position / map.tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	for building in WorldState.get_state("neutral_buildings"):
		var pos = (building.global_position / map.tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	path_finder = Finder.JumpPointFinder.new()
	path_line = Line2D.new()
	path_line.name = "unit_path_line"
	map.fog.add_sibling(path_line)


func draw(unit):
	var should_draw = false
	var has_path = false
	if unit:
		has_path = not unit.current_path.is_empty()
		should_draw = unit.is_controllable() and (has_path or unit.final_destiny)
	if should_draw:
		Navigation.path_line.show()
		var pool = PackedVector2Array()
		pool.append(unit.global_position)
		if has_path:
			pool.append_array(unit.current_path)
		elif unit.current_destiny and unit.current_destiny != Vector2.ZERO:
			pool.append(unit.current_destiny)
		elif unit.final_destiny and unit.final_destiny != Vector2.ZERO:
			pool.append(unit.final_destiny)
		Navigation.path_line.points = pool
		if unit.team == "blue":
			Navigation.path_line.default_color = Color(0.4, 0.6, 1, 0.5)
		else:
			Navigation.path_line.default_color = Color(1, 0.3, 0.3, 0.5)
	else:
		Navigation.path_line.hide()
