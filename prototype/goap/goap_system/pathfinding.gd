extends Node

# self = Goap.path


# PATHFIND GRID
var path_grid
var path_finder
var path_line
var navigation_region: NavigationRegion2D


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
	setup_native_navigation(WorldState.get_state("map"))
	# setup finder
	path_finder = Finder.JumpPointFinder.new()
	# add movement line indicator
	path_line = Line2D.new()
	path_line.name = "unit_path_line"
	WorldState.get_state("map").fog.add_sibling(path_line)


func setup_native_navigation(map):
	if is_instance_valid(navigation_region):
		navigation_region.queue_free()

	var navigation_polygon = NavigationPolygon.new()
	var tile_size = map.tile_size
	var vertices := PackedVector2Array()
	var polygons: Array[PackedInt32Array] = []
	for y in range(path_grid.height):
		for x in range(path_grid.width):
			if not path_grid.isWalkableAt(x, y):
				continue
			var left = x * tile_size
			var top = y * tile_size
			var right = min(left + tile_size, map.size.x)
			var bottom = min(top + tile_size, map.size.y)
			if right <= left or bottom <= top:
				continue
			var first_vertex = vertices.size()
			vertices.append_array(PackedVector2Array([
				Vector2(left, top),
				Vector2(right, top),
				Vector2(right, bottom),
				Vector2(left, bottom)
			]))
			polygons.append(PackedInt32Array([
				first_vertex,
				first_vertex + 1,
				first_vertex + 2,
				first_vertex + 3
			]))

	navigation_polygon.vertices = vertices
	for polygon in polygons:
		navigation_polygon.add_polygon(polygon)
	navigation_region = NavigationRegion2D.new()
	navigation_region.name = "generated_navigation_region"
	navigation_region.navigation_polygon = navigation_polygon
	map.add_child(navigation_region)


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
		unit.current_path = []
		Goap.move.end(unit)


func find(g1, g2):
	var native_path = find_native_path(g1, g2)
	if native_path.size() > 0:
		return native_path
	return find_custom_path(g1, g2)


func find_custom_path(g1, g2):
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
	return []


func find_native_path(from: Vector2, to: Vector2) -> Array:
	var map = WorldState.get_state("map")
	if not map or not map.get_world_2d():
		return []
	var nav_map = map.get_world_2d().navigation_map
	if nav_map == null:
		return []
	var path = NavigationServer2D.map_get_path(nav_map, from, to, true)
	if path.size() <= 1:
		return []
	var converted = []
	for point in path:
		converted.append(point)
	return converted


func in_limits(p):
	return ((p.x > 0 and p.y > 0) and (p.x < path_grid.width and p.y < path_grid.height))


func navigate_to(unit, target_point: Vector2):
	if not unit or target_point == Vector2.ZERO:
		return
	var native_path = find_native_path(unit.global_position, target_point)
	if native_path.size() > 1:
		unit.current_path.clear()
		unit.current_destiny = target_point
		unit.final_destiny = target_point
		unit.set_navigation_target(target_point)
		Goap.move.move(unit, target_point)
		return
	var custom_path = find_custom_path(unit.global_position, target_point)
	if custom_path.size() > 0:
		start(unit, custom_path)
		return
	unit.current_path = []
	unit.current_destiny = target_point
	unit.final_destiny = target_point
	unit.set_navigation_target(target_point)
	Goap.move.move(unit, target_point)


func start(unit, new_path):
	if new_path and not new_path.is_empty():
		var next_point = new_path.pop_front()
		unit.current_path = new_path
		unit.current_destiny = next_point
		unit.set_navigation_target(next_point)
		Goap.advance.point(unit, next_point)


func smart(unit, path, cb="advance"):
	if path and path.size():
		var new_path = unit.cut_path(path)
		var next_point = new_path.pop_front()
		unit.current_path = new_path
		unit.current_destiny = next_point
		unit.set_navigation_target(next_point)
		Goap[cb].point(unit, next_point)


func resume_lane(unit):
	var lane = unit.agent.get_state("lane")
	var new_path = Goap.path.new_lane_path(lane, unit.team)
	start(unit,new_path)


func next(unit):
	if not unit.current_path.is_empty():
		start(unit,unit.current_path)
	else:
		Goap.move.stop(unit)


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
		pool.append(unit.global_position)
		# end
		if has_path:
			pool.append_array(unit.current_path)
		elif unit.current_destiny and unit.current_destiny != Vector2.ZERO:
			pool.append(unit.current_destiny)
		elif unit.final_destiny and unit.final_destiny != Vector2.ZERO:
			pool.append(unit.final_destiny)
			
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
	Goap.move.smart(unit, lane_start)
