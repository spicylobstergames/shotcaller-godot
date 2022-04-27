extends Node
var game:Node


const teleport_time = 3
const teleport_max_distance = 100


# PATHFIND GRID
const _GridGD = preload("../../map/pathfind/grid.gd")
const _JumpPointFinderGD = preload("../../map/pathfind/jump_point_finder.gd")
var path_grid
var path_finder



func _ready():
	game = get_tree().get_current_scene()


func setup_pathfind():
	# get tiles
	var walls_rect = game.map.walls.get_used_rect()
	var walls_size =  walls_rect.size
	#setup grid
	var Grid = _GridGD.new().Grid
	path_grid = Grid.new(walls_size.x, walls_size.y)
	# add tile walls
	for cell in game.map.walls.get_used_cells():
		game.map.blocks.create_block(cell.x, cell.y)
		path_grid.setWalkableAt(cell.x, cell.y, false)
	# add building units
	for building in game.player_buildings:
		var pos = (building.global_position / game.map.tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	for building in game.enemy_buildings:
		var pos = (building.global_position / game.map.tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	# setup finder
	var Jpf = _JumpPointFinderGD.new().JumpPointFinder
	path_finder = Jpf.new()


func find_path(g1, g2):
	var cell_size = game.map.tile_size
	var half = game.map.half_tile_size
	var p1 = (g1 / cell_size).floor()
	var p2 = (g2 / cell_size).floor()
	if in_limits(p1) and in_limits(p2):
		var solved_path = path_finder.findPath(p1.x, p1.y, p2.x, p2.y, path_grid.clone())
		var path = []
		for i in range(1, solved_path.size()):
			var item = solved_path[i]
			path.append(Vector2(half + (item[0] * cell_size), half + (item[1] * cell_size)))
		return path


func in_limits(p):
	return ((p.x > 0 and p.y > 0) and (p.x < path_grid.width and p.y < path_grid.height)) 


func follow(unit, path, cb):
	if path and path.size():
		var next_point = path.pop_front()
		unit.current_path = path
		game.unit[cb].start(unit, next_point)


func follow_next(unit):
	follow(unit, unit.current_path, unit.behavior)


func change_lane(unit, point):
	var lane = game.utils.closer_lane(point)
	var path = game.map[lane].duplicate()
	if unit.team == "red": path.invert()
	var lane_start = path.pop_front()
	unit.lane = lane
	game.unit.move.smart_move(unit, lane_start)



func follow_lane(unit):
	if !unit.current_path:
		var lane = unit.lane
		var path = game.map[lane].duplicate()
		if unit.team == "red": path.invert()
		if unit.type != 'leader': 
			follow(unit, path, "advance")
		else: smart_follow(unit, path, "advance")



func smart_follow(unit, path, cb):
	if path and path.size():
		var new_path = game.utils.cut_path(unit, path)
		var next_point = new_path.pop_front()
		unit.current_path = new_path
		game.unit[cb].start(unit, next_point)



func teleport(unit, point):
	game.ui.controls.teleport_button.disabled = true
	var building = game.utils.closer_building(point, unit.team)
	var distance = building.global_position.distance_to(point)
	game.control_state = "selection"
	game.ui.controls.teleport_button.disabled = false
	game.ui.controls.teleport_button.pressed = false
	game.unit.move.stand(unit)
	unit.channeling = true
	
	yield(get_tree().create_timer(teleport_time), "timeout")
	if unit.channeling:
		unit.working = false
		unit.channeling = false
		var new_position = point
		# prevent teleport into buildings
		var min_distance = 2 * building.collision_radius + unit.collision_radius
		if distance <= min_distance:
			var offset = (point - building.global_position).normalized()
			new_position = building.global_position + (offset * min_distance)
		# limit teleport range
		if distance > teleport_max_distance:
			var offset = (point - building.global_position).normalized()
			new_position = building.global_position + (offset * teleport_max_distance)

		unit.global_position = new_position
		unit.lane = building.lane
		unit.current_path = []
