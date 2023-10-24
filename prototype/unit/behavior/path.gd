extends Node

# self = Behavior.path


# PATHFIND GRID
var path_grid
var path_finder
var path_line


func setup_pathfind():
	# get tiles
	var walls_size = Vector2(
		floor(WorldState.get_state("map").size.x / WorldState.get_state("map").tile_size)+1,
		floor(WorldState.get_state("map").size.y / WorldState.get_state("map").tile_size)+1
	)
	#setup grid
	var grid = Finder.GridGD.new().Grid
	path_grid = grid.new(walls_size.x, walls_size.y)
	# add tile walls
	var walls_tile = WorldState.get_state("map").walls
	var used_cells = walls_tile.get_used_cells(0)
	
	for cell in used_cells:
		var team = "blue" if (walls_tile.get_cell_source_id(0, cell) == 0) else "red"
		Collisions.create_block(cell.x, cell.y, team)
		path_grid.setWalkableAt(cell.x, cell.y, false)
	# add building units
	for building in WorldState.get_state("player_buildings"):
		var pos = (building.global_position / WorldState.get_state("map").tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	for building in WorldState.get_state("enemy_buildings"):
		var pos = (building.global_position / WorldState.get_state("map").tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	for building in WorldState.get_state("neutral_buildings"):
		var pos = (building.global_position / WorldState.get_state("map").tile_size).floor()
		path_grid.setWalkableAt(pos.x, pos.y, false)
	# setup finder
	path_finder = Finder.JumpPointFinder.new()
	# add movement line indicator
	path_line = Line2D.new()
	path_line.name = "unit_path_line"
	WorldState.get_state("map").fog.add_sibling(path_line)


func setup_unit_path(unit, path):
	unit.current_path = path
	if not unit.unit_arrived.is_connected(on_arrive):
		unit.unit_arrived.connect(on_arrive.bind(unit))


func new_lane_path(lane, team):
	if lane in WorldState.get_state("lanes"):
		var path = WorldState.get_state("lanes")[lane].duplicate()
		var map = WorldState.get_state("map")
		if team == "blue" and map.has_node("buildings/red/castle"):
			path.append(map.get_node("buildings/red/castle").global_position)
		if team == "red" and map.has_node("buildings/blue/castle"): 
			path.reverse()
			path.append(map.get_node("buildings/blue/castle").global_position)
		return path


func on_arrive(unit):
	if unit.current_path.size() > 0:
		next(unit)
	else:
		Behavior.move.end(unit)


func find(g1, g2):
	var cell_size = WorldState.get_state("map").tile_size
	var half = WorldState.get_state("map").half_tile_size
	var p1 = (g1 / cell_size).floor()
	var p2 = (g2 / cell_size).floor()
	if in_limits(p1) and in_limits(p2):
		var solved_path = path_finder.findPath(p1.x, p1.y, p2.x, p2.y, path_grid.clone())
		# path to global_position
		var path = []
		for i in range(1, solved_path.size()):
			var item = solved_path[i]
		# int array[x,y] to float dict Vector2(x,y)
			path.append(Vector2(half + (item[0] * cell_size), half + (item[1] * cell_size)))
		return path


func in_limits(p):
	return ((p.x > 0 and p.y > 0) and (p.x < path_grid.width and p.y < path_grid.height)) 


func start(unit, new_path):
	if new_path and not new_path.is_empty():
		var next_point = new_path.pop_front()
		unit.current_path = new_path
		Behavior.advance.point(unit, next_point)


func smart(unit, path, cb="advance"):
	if path and path.size():
		var new_path = unit.cut_path(path)
		var next_point = new_path.pop_front()
		unit.current_path = new_path
		Behavior[cb].point(unit, next_point)


func resume_lane(unit):
	var lane = unit.agent.get_state("lane")
	var new_path = Behavior.path.new_lane_path(lane, unit.team)
	start(unit,new_path)


func next(unit):
	if not unit.current_path.is_empty():
		start(unit,unit.current_path)
	else:
		Behavior.move.stop(unit)


func draw(unit):
	var should_draw = false
	var has_path = false
	
	if unit:
		has_path = not unit.current_path.is_empty()
		should_draw = unit.is_controllable() and (has_path or unit.final_destiny)
	
	if should_draw:
		path_line.show()
		var pool = PackedVector2Array()
		# start
		pool.push_back(unit.global_position)
		# end
		if has_path:
			pool.append_array(unit.current_path)
		elif unit.current_destiny and unit.current_destiny != Vector2.ZERO:
			pool.push_back(unit.current_destiny)
		elif unit.final_destiny and unit.final_destiny != Vector2.ZERO:
			pool.push_back(unit.final_destiny)
			
		path_line.points = pool
		
		if unit.team == "blue":
			path_line.default_color = Color(0.4,0.6,1, 0.1)
		else: path_line.default_color = Color(1,0.3,0.3, 0.1)
	# todo add line shader
	# https://www.reddit.com/r/godot/comments/btsrxc/shaders_for_line2d_are_tricky_does_anyone_use_them/
	else: path_line.hide()


func change_lane(unit, point):
	var lane = Utils.closer_lane(point)
	var path = lane.duplicate()
	if unit.team == "red": path.reverse()
	var lane_start = path.pop_front()
	unit.agent.set_state("lane", lane)
	# unit.agent.set_state("order_behavior", "move")
	Behavior.move.smart(unit, lane_start)
