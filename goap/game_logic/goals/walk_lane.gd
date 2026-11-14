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
	# This runs on EVERY plan re-install (the [Move] plan completes each tick
	# while arrived_at_destination is false), so it must not touch an
	# in-progress route: re-deriving and re-popping the nearest waypoint
	# every tick pinned units at the lane's first waypoint (nearest == where
	# they stand) and overwrote the destiny that on_arrive had just advanced.
	#
	# Re-derive ONLY when the current path is gone or was polluted by combat
	# navigation (PursueEnemy -> Navigate.move -> follow_path overwrites
	# current_path with tile paths between fight points — those are not lane
	# waypoints). An in-progress route's remaining points all come from the
	# lane definition, so membership is a cheap pollution test.
	var lane_path = get_lane_path(agent.get_state("lane"), unit.team)
	if lane_path.is_empty():
		return
	var current: Array = unit.current_path
	var is_lane_route = not current.is_empty()
	for point in current:
		if not lane_path.has(point):
			is_lane_route = false
			break
	if is_lane_route:
		return
	unit.current_path = unit.cut_path(lane_path)
	# The planner runs BEFORE goal.enter and may have skipped Navigate
	# (has_destiny stale-true) while arrived_at_destination is stale-true
	# from on_arrive — either would freeze the fresh route. Navigate.enter
	# resets the arrived fact (documented lifecycle) and pops the first
	# waypoint into current_destiny + starts stepping. It runs at most once
	# per re-derivation: afterwards the route's remaining points are lane
	# waypoints and the on_arrive -> Navigate.next loop drives progression.
	Goap.get_action("Navigate").enter(agent)


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
	
