extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "WalkLane"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var lane = agent.get_state("lane", "")
	if (
		unit.target
		or not unit.moves
		or unit.dead
		or lane == ""
		or lane not in WorldState.get_state("lanes")
		or agent.get_state("has_player_command", false)
		or agent.get_state("is_retreating", false)
		or not agent.get_state("ready_to_fight", true)
		or agent.get_state("is_channeling", false)
		or agent.get_state("lane_route_finished", false)):
		return false

	return true

func enter(agent):
	var unit = agent.get_unit()
	# Always re-derive the lane route from the lane definition instead of
	# keeping unit.current_path: combat navigation (PursueEnemy ->
	# Navigate.move -> follow_path) overwrites current_path with tile paths
	# between arbitrary fight points, so the old "keep the existing path"
	# guard made units walk toward wherever the fight happened instead of
	# back to their lane. Cutting the fresh route to the NEAREST waypoint
	# keeps mid-route resume (same semantics as MoveAction.teleport's
	# resume_lane) without sending the unit all the way back to the lane
	# start. Navigate.enter consumes the first waypoint via follow_path, so
	# only slice here — do not follow.
	var lane_path = get_lane_path(agent.get_state("lane"), unit.team)
	if not lane_path.is_empty():
		unit.current_path = unit.cut_path(lane_path)


func priority(_agent) -> int:
	return 2


func get_desired_state(_agent) -> Dictionary:
	return {"lane_route_finished": true}


func get_lane_path(lane: String, team: String, include_enemy_castle := true) -> Array:
	var lanes = WorldState.get_state("lanes", {})
	if lane not in lanes:
		return []

	var path: Array = lanes[lane].duplicate()
	if team == "red":
		path.reverse()

	if include_enemy_castle:
		var castle_team = "red" if team == "blue" else "blue" if team == "red" else ""
		if castle_team:
			var castle = WorldState.get_state("map").get_node_or_null(
				"buildings/" + castle_team + "/castle"
			)
			if castle:
				path.append(castle.global_position)

	return path


func closest_lane(point: Vector2) -> String:
	var closest_lane_name := ""
	var closest_distance := INF
	for lane in WorldState.get_state("lanes", {}):
		for lane_point in WorldState.get_state("lanes")[lane]:
			var distance = point.distance_to(lane_point)
			if distance < closest_distance:
				closest_distance = distance
				closest_lane_name = lane
	return closest_lane_name


func change_lane(unit, lane_point: Vector2) -> void:
	var lane = closest_lane(lane_point)
	if lane.is_empty():
		return

	var path = get_lane_path(lane, unit.team, false)
	if path.is_empty():
		return

	unit.agent.set_state("lane", lane)
	unit.agent.set_state("lane_route_finished", false)
	unit.agent.erase_state("lane_resume_path")
	unit.agent.set_state("resume_path", false)
	unit.current_path.clear()
	var lane_start = path.pop_front()
	Goap.get_action("Navigate").move(unit, lane_start)
	unit.current_path.append_array(path)


func resume_lane(unit) -> void:
	var lane = unit.agent.get_state("lane", "")
	var path = get_lane_path(lane, unit.team)
	Goap.get_action("Navigate").cut_path(unit, path)


func on_arrive(agent) -> void:
	var route_finished = agent.get_unit().current_path.is_empty()
	if route_finished:
		agent.set_state("lane_route_finished", true)
		agent.erase_state("lane_resume_path")
	
