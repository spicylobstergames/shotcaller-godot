extends "res://goap/goap_system/action_contract.gd"

var path_grid
var path_finder
var path_line
var navigation_region: NavigationRegion2D


func get_class_name() -> String:
	return "NavigateAction"


func is_valid(agent) -> bool:
	return agent.get_unit().moves and agent.get_state("has_path", false)


func get_cost(_agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return {"arrived_at_destination": true}


func perform(agent, _delta) -> bool:
	return agent.get_state("arrived_at_destination", false)


func enter(agent):
	var unit = agent.get_unit()
	var new_path = unit.cut_path(unit.current_path)
	agent.set_state("arrived_at_destination", false)
	if not new_path.is_empty():
		start(unit, new_path)
	else:
		agent.set_state("arrived_at_destination", true)


func smart(unit, final_destiny):
	point(unit, final_destiny, true)


func point(unit, final_destiny, smart_move = false):
	Goap.attack.set_target(unit, null)
	if final_destiny and Goap.move.in_bounds(final_destiny):
		unit.final_destiny = final_destiny
		if unit.attacks and not unit.agent.get_state("is_stunned"):
			var path = unit.current_path
			if smart_move:
				path = find(unit.global_position, unit.final_destiny)
				if path:
					unit.current_path = path
			var enemies = unit.get_units_in_sight({"team": unit.opponent_team()})
			var at_final_destination = (
				unit.global_position.distance_to(unit.final_destiny)
				< WorldState.get_state("map").half_tile_size
			)
			var has_path = path and not path.is_empty()
			if enemies.is_empty():
				if not at_final_destination:
					move(unit, unit.final_destiny, smart_move)
				elif has_path:
					start(unit, path)
			else:
				var target = Goap.attack.select_target(unit, enemies)
				if not target:
					if not at_final_destination:
						move(unit, unit.final_destiny, smart_move)
					elif has_path:
						start(unit, path)
				else:
					Goap.attack.set_target(unit, target)
					var target_position = target.global_position + target.collision_position
					if Goap.attack.in_range(unit, target):
						Goap.attack.point(unit, target_position)
					else:
						move(unit, target_position, smart_move)


func move(unit, final_destiny, smart_move):
	if unit.moves and final_destiny:
		if smart_move:
			navigate_to(unit, final_destiny)
		else:
			Goap.move.move(unit, final_destiny)
	else:
		stop(unit)


func resume(unit):
	point(unit, null)


func react(target, attacker):
	point(target, attacker.global_position)


func ally_attacked(target, attacker):
	var allies = target.get_units_in_sight({"team": target.team})
	for ally in allies:
		react(ally, attacker)


func stop(unit):
	Goap.move.stop(unit)


func setup_pathfind():
	var map = WorldState.get_state("map")
	var walls_size = Vector2(
		floor(map.size.x / map.tile_size) + 1, floor(map.size.y / map.tile_size) + 1
	)
	var grid = Finder.GridGD.new().Grid
	path_grid = grid.new(walls_size.x, walls_size.y)
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
	setup_native_navigation(map)
	path_finder = Finder.JumpPointFinder.new()
	path_line = Line2D.new()
	path_line.name = "unit_path_line"
	map.fog.add_sibling(path_line)


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
			vertices.append_array(
				PackedVector2Array(
					[
						Vector2(left, top),
						Vector2(right, top),
						Vector2(right, bottom),
						Vector2(left, bottom)
					]
				)
			)
			polygons.append(
				PackedInt32Array(
					[first_vertex, first_vertex + 1, first_vertex + 2, first_vertex + 3]
				)
			)
	navigation_polygon.vertices = vertices
	for polygon in polygons:
		navigation_polygon.add_polygon(polygon)
	navigation_region = NavigationRegion2D.new()
	navigation_region.name = "generated_navigation_region"
	navigation_region.navigation_polygon = navigation_polygon
	map.add_child(navigation_region)


func setup_unit_path(unit, path):
	unit.current_path = path


func new_lane_path(lane, team):
	if lane in WorldState.get_state("lanes"):
		var path = WorldState.get_state("lanes")[lane].duplicate()
		var map = WorldState.get_state("map")
		if team == "blue":
			var castle = map.get_node_or_null("buildings/red/castle")
			if castle:
				path.append(castle.global_position)
		if team == "red":
			path.reverse()
			var castle = map.get_node_or_null("buildings/blue/castle")
			if castle:
				path.append(castle.global_position)
		return path
	return []


func find(from: Vector2, to: Vector2) -> Array:
	if Goap.use_native_pathfinding:
		return find_native_path(from, to)
	return find_custom_path(from, to)


func find_custom_path(from: Vector2, to: Vector2) -> Array:
	var cell_size = WorldState.get_state("map").tile_size
	var half = WorldState.get_state("map").half_tile_size
	var start_cell = (from / cell_size).floor()
	var target_cell = (to / cell_size).floor()
	if in_limits(start_cell) and in_limits(target_cell):
		var solved_path = path_finder.findPath(
			start_cell.x, start_cell.y, target_cell.x, target_cell.y, path_grid.clone()
		)
		var path = []
		for index in range(1, solved_path.size()):
			var item = solved_path[index]
			path.append(Vector2(half + item[0] * cell_size, half + item[1] * cell_size))
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
	for index in range(1, path.size()):
		converted.append(path[index])
	return converted


func in_limits(point):
	return point.x > 0 and point.y > 0 and point.x < path_grid.width and point.y < path_grid.height


func navigate_to(unit, target_point: Vector2):
	if not unit or target_point == Vector2.ZERO:
		return
	if Goap.use_native_pathfinding and Goap.use_native_movement:
		var native_path = find_native_path(unit.global_position, target_point)
		if not native_path.is_empty() or _is_same_tile(unit.global_position, target_point):
			unit.current_path.clear()
			unit.current_destiny = target_point
			unit.final_destiny = target_point
			unit.set_navigation_target(target_point)
			Goap.move.move(unit, target_point)
			return
	var path = find(unit.global_position, target_point)
	if not path.is_empty():
		unit.final_destiny = target_point
		start(unit, path)
		return
	if _is_same_tile(unit.global_position, target_point):
		unit.current_path.clear()
		unit.current_destiny = target_point
		unit.final_destiny = target_point
		unit.set_navigation_target(target_point)
		Goap.move.move(unit, target_point)


func _is_same_tile(from: Vector2, to: Vector2) -> bool:
	var tile_size = WorldState.get_state("map").tile_size
	return (from / tile_size).floor() == (to / tile_size).floor()


func start(unit, new_path):
	if new_path and not new_path.is_empty():
		var path = new_path.duplicate()
		var next_point = path.pop_front()
		unit.current_path = path
		unit.current_destiny = next_point
		unit.set_navigation_target(next_point)
		Goap.move.point(unit, next_point)


func follow_path(unit, path):
	if path and path.size():
		var new_path = unit.cut_path(path)
		start(unit, new_path)


func resume_lane(unit):
	var lane = unit.agent.get_state("lane")
	start(unit, new_lane_path(lane, unit.team))


func next(unit):
	if not unit.current_path.is_empty():
		start(unit, unit.current_path)
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
		pool.append(unit.global_position)
		if has_path:
			pool.append_array(unit.current_path)
		elif unit.current_destiny and unit.current_destiny != Vector2.ZERO:
			pool.append(unit.current_destiny)
		elif unit.final_destiny and unit.final_destiny != Vector2.ZERO:
			pool.append(unit.final_destiny)
		path_line.points = pool
		if unit.team == "blue":
			path_line.default_color = Color(0.4, 0.6, 1, 0.1)
		else:
			path_line.default_color = Color(1, 0.3, 0.3, 0.1)
	else:
		path_line.hide()


func change_lane(unit, lane_point):
	var lane = Utils.closer_lane(lane_point)
	var path = WorldState.get_state("lanes")[lane].duplicate()
	if unit.team == "red":
		path.reverse()
	var lane_start = path.pop_front()
	unit.agent.set_state("lane", lane)
	Goap.move.smart(unit, lane_start)
