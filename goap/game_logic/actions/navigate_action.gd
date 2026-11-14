extends "res://goap/goap_system/action_contract.gd"


func get_class_name() -> String:
	return "Navigate"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.moves


func get_preconditions() -> Dictionary:
	return {
		"is_stunned": false
	}


#func get_cost(_agent) -> int:
#	return 1


func get_effects() -> Dictionary:
	return {
		"has_destiny": true
	}


func perform(agent, _delta) -> bool:
	var has_destiny = agent.get_state("has_destiny", false)
	return has_destiny

func enter(agent):
	var unit = agent.get_unit()
	#var has_lane = agent.get_state("lane", "") != ""
	
	agent.set_state("arrived_at_destination", false)
	
	#if has_lane:
		#agent.set_state("lane_route_finished", false)
		#if agent.get_state("lane_resume_path", null) is Array:
			#unit.current_path = agent.get_state("lane_resume_path")
			#agent.erase_state("lane_resume_path")
	
	#if (agent.get_state("resume_path", false)):
		#agent.erase_state("resume_path")
		#cut_path(unit, unit.current_path)
	#else:
	follow_path(unit, unit.current_path)
	


#func exit(agent):
	#if (not agent.get_state("lane_route_finished", false)):
		#var unit = agent.get_unit()
		#var lane_path = unit.current_path.duplicate()
		#agent.set_state("lane_resume_path", lane_path)
	#elif agent.get_state("has_path", false):
		#agent.set_state("resume_path", true)
	#else:
		#agent.set_state("resume_path", false)
		#agent.erase_state("lane_resume_path")


func point(unit, final_destiny):
	unit.agent.set_state("target", null)
	if final_destiny and Goap.get_action("Move").in_bounds(final_destiny):
		unit.final_destiny = final_destiny
		if unit.attacks and not unit.agent.get_state("is_stunned"):
			var path = unit.current_path
			if !path or path.is_empty():
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
					move(unit, unit.final_destiny)
				elif has_path:
					follow_path(unit, path)
			else:
				var choose_target = Goap.get_action("ChooseTarget")
				var target = choose_target.select_target(unit, enemies)
				if not target:
					if not at_final_destination:
						move(unit, unit.final_destiny)
					elif has_path:
						follow_path(unit, path)
				else:
					unit.agent.set_state("target", target)
					var target_position = target.global_position + target.collision_position
					if choose_target.in_range(unit, target):
						Goap.get_action("AttackEnemy").point(unit, target_position)
					else:
						move(unit, target_position)


func stop(unit):
	Goap.get_action("Move").stop(unit)


#func setup_unit_path(unit, path):
#	unit.current_path = path


func find(from: Vector2, to: Vector2) -> Array:
	return find_custom_path(from, to)


func find_custom_path(from: Vector2, to: Vector2) -> Array:
	var cell_size = WorldState.get_state("map").tile_size
	var half = WorldState.get_state("map").half_tile_size
	var start_cell = (from / cell_size).floor()
	var target_cell = (to / cell_size).floor()
	if (
		in_limits(start_cell)
		and in_limits(target_cell)
		and Navigation.path_grid.isWalkableAt(start_cell.x, start_cell.y)
		and Navigation.path_grid.isWalkableAt(target_cell.x, target_cell.y)
	):
		var solved_path = Navigation.path_finder.findPath(
			start_cell.x, start_cell.y, target_cell.x, target_cell.y, Navigation.path_grid
		)
		var path = []
		for index in range(1, solved_path.size()):
			var item = solved_path[index]
			path.append(Vector2(half + item[0] * cell_size, half + item[1] * cell_size))
		return path
	return []


func in_limits(target_point):
	return (
		target_point.x >= 0 and
		target_point.y >= 0 and
		target_point.x < Navigation.path_grid.width and 
		target_point.y < Navigation.path_grid.height
	)


func move(unit, target_point: Vector2) -> bool:
	if not unit or target_point == Vector2.ZERO:
		return false
	var path = find(unit.global_position, target_point)
	if not path.is_empty():
		unit.final_destiny = target_point
		follow_path(unit, path)
		return true
	if _is_same_tile(unit.global_position, target_point):
		unit.current_path.clear()
		unit.current_destiny = target_point
		unit.final_destiny = target_point
		Goap.get_action("Move").point(unit, target_point)
		return true
	# No route to the target (e.g. it sits on a blocked tile — buildings are
	# marked unwalkable in Navigation.setup_pathfind, and the JPS returns no
	# path into them). Callers MUST handle the false return: silently doing
	# nothing here left units frozen forever "pursuing" a tower they could
	# never reach (destiny stayed zeroed after the combat exit's Move.stop).
	return false


func _is_same_tile(from: Vector2, to: Vector2) -> bool:
	var tile_size = WorldState.get_state("map").tile_size
	return (from / tile_size).floor() == (to / tile_size).floor()


func follow_path(unit, new_path):
	if new_path and not new_path.is_empty():
		var path = new_path.duplicate()
		var next_point = path.pop_front()
		unit.current_path = path
		unit.agent.set_state("has_path", true)
		unit.current_destiny = next_point
		unit.agent.set_state("has_destiny", true)
		# Hand the waypoint to the movement driver. Only state == "move"
		# units are stepped (Collisions.physics_process), and Move.move is
		# the one place that sets it — plans without a Move action (e.g. the
		# PursueEnemy plan [ChooseTarget, PursueEnemy, AttackEnemy]) used to
		# set current_destiny here and then stand still forever "pursuing" a
		# target they could never reach (see COVERAGE.md known bugs).
		Goap.get_action("Move").move(unit, next_point)


func cut_path(unit, path):
	if path and path.size():
		var new_path = unit.cut_path(path)
		follow_path(unit, new_path)


func resume_path(unit):
	cut_path(unit, unit.current_path)


func next(unit):
	if not unit.current_path.is_empty():
		follow_path(unit, unit.current_path)
	else:
		Goap.get_action("Move").stop(unit)
