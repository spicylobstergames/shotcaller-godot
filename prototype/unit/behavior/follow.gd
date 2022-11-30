extends Node
var game:Node


var path_line

const teleport_time = 3
const teleport_max_distance = 100


# PATHFIND GRID
const _GridGD = preload("../../map/pathfind/grid.gd")
const _JumpPointFinderGD = preload("../../map/pathfind/jump_point_finder.gd")
var path_grid
var path_finder



func _ready():
	game = get_tree().get_current_scene()
	path_line = Line2D.new()


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
	for building in game.neutral_buildings:
		var pos = (building.global_position / game.map.tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	# setup finder
	var Jpf = _JumpPointFinderGD.new().JumpPointFinder
	path_finder = Jpf.new()
	
	game.map.add_child(path_line)


func find_path(g1, g2):
	var cell_size = game.map.tile_size
	var half = game.map.half_tile_size
	var p1 = (g1 / cell_size).floor()
	var p2 = (g2 / cell_size).floor()
	if in_limits(p1) and in_limits(p2):
		var solved_path = path_finder.findPath(p1.x, p1.y, p2.x, p2.y, path_grid.clone())
		# path to global_position
		# int array[x,y] to float dict Vector2(x,y)float 
		var path = []
		for i in range(1, solved_path.size()):
			var item = solved_path[i]
			path.append(Vector2(half + (item[0] * cell_size), half + (item[1] * cell_size)))
		return path


func in_limits(p):
	return ((p.x > 0 and p.y > 0) and (p.x < path_grid.width and p.y < path_grid.height)) 


func path(unit, path, cb):
	if path and path.size():
		var next_point = path.pop_front()
		unit.current_path = path# I don't think this is needed
		var node:Behaviors = Behavior #hack
		node[cb].point(unit, next_point)


func next(unit):
	path(unit, unit.current_path, unit.behavior)


func draw_path(unit):
	if unit and (unit.current_path or unit.current_destiny or unit.objective):
		path_line.visible = true
		var pool = PoolVector2Array()
		# start
		pool.push_back(unit.global_position)
		 # end
		if unit.current_path:
			pool.append_array(unit.current_path)
		elif unit.current_path:
			pool.push_back(unit.current_path)
		elif unit.objective:
			pool.push_back(unit.objective)
			
		if unit.team == "blue":
			path_line.default_color = Color(0.4,0.6,1, 0.3)
		else: path_line.default_color = Color(1,0.3,0.3, 0.3)
		path_line.points = pool
	# todo add line shader
	# https://www.reddit.com/r/godot/comments/btsrxc/shaders_for_line2d_are_tricky_does_anyone_use_them/
	else: path_line.visible = false


func change_lane(unit, point):
	var lane = game.utils.closer_lane(point)
	var path = game.map.lanes_paths[lane].duplicate()
	if unit.team == "red": path.invert()
	var lane_start = path.pop_front()
	unit.lane = lane
	Behavior.move.smart(unit, lane_start, "move")


func smart(unit, path, cb):
	if path and path.size():
		var new_path = unit.cut_path(path)
		var next_point = new_path.pop_front()
		unit.current_path = new_path
		var node:Behaviors = Behavior #hack, it comes back as that Behaviors is null if you array access it
		node[cb].point(unit, next_point)


func teleport(unit, point):
	game.ui.controls_menu.teleport_button.disabled = true
	var building = game.utils.closer_building(point, unit.team)
	var distance = building.global_position.distance_to(point)
	game.control_state = "selection"
	game.ui.controls_menu.teleport_button.disabled = false
	game.ui.controls_menu.teleport_button.pressed = false
	Behavior.move.stand(unit)
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
