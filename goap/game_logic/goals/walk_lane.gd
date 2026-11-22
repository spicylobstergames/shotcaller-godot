# =============================================================================
# GOAP-GUIDE: WalkLane - goal (goap/game_logic/goals/walk_lane.gd)
# =============================================================================
# Purpose   : Default behavior -- walk the unit's assigned lane toward the
#             enemy castle.
# priority  : 2 (above NeedLumber, below combat/safety goals)
# desired   : {"lane_route_finished": true}
# is_valid  : lane set and known, no unit.target, moves, not dead, no player
#             command, not retreating, ready_to_fight, not channeling, and
#             route not already finished.
# enter     : re-derives the route ONLY when it is missing or polluted by
#             combat navigation; otherwise preserves the in-progress lane route
#             and re-pops the next waypoint if the destiny was zeroed.
# arrival  : NONE on purpose -- lane completion must not be set on arrival
#             (lane_route_finished is write-once and would disable the goal
#             forever; see the note in the body).
# Helpers   : get_lane_path / closest_lane / change_lane / resume_lane.
# Traps     : enter() runs on EVERY plan re-install (Move completes each tick).
#             Re-deriving there pins units at the lane start -- read the long
#             comment in enter() before touching it.
#             lane_route_finished is write-once: only change_lane()/teleport
#             clear it, and is_valid() treats it as a hard gate.
# See       : tests/unit/test_attack_lifecycle.gd (lane-route cases).
# =============================================================================

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
	# they stand) and overwrote the destiny the arrival had just advanced.
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
		# The route is intact, but its handoff to the stepper may have been
		# lost: leaving a combat action zeroes current_destiny (PursueEnemy/
		# AttackEnemy exit -> Move.stop), and Move.enter then walks toward
		# the map origin. Re-pop the NEXT waypoint without re-deriving —
		# this is what keeps the unit on its lane after a fight.
		if unit.current_destiny == Vector2.ZERO:
			Goap.get_action("Navigate").enter(agent)
		return
	unit.current_path = unit.cut_path(lane_path)
	# The planner runs BEFORE goal.enter and may have skipped Navigate
	# (has_destiny stale-true) while arrived_at_destination is stale-true
	# from the last arrival — either would freeze the fresh route. Navigate.enter
	# resets the arrived fact (documented lifecycle) and pops the first
	# waypoint into current_destiny + starts stepping. It runs at most once
	# per re-derivation: afterwards the route's remaining points are lane
	# waypoints and the arrival -> Navigate.next loop drives progression.
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


# Deliberately NO arrival hook.
#
# This used to set lane_route_finished = true whenever current_path was empty,
# which looked correct but froze units: lane_route_finished is a WRITE-ONCE
# fact (only change_lane() and Move.teleport() clear it) and is_valid() treats
# it as a hard gate. The old arrival signal dispatch (Collisions -> unit.on_arrive
# -> Agent.on_arrive -> this hook) made the first empty-path arrival -- e.g. the
# terminal lane waypoint at the enemy castle -- disable WalkLane for the rest
# of that unit's life. After the fight it had no valid goal and stood still.
# (Arrival is no longer signal-dispatched at all: it is a GOAP state
# transition latched by Collisions -> ArriveAtDestination.advance_path.)
#
# Regression: tests/unit/test_arrival_dispatch.gd, "an arrival must NOT
# permanently disable WalkLane".
#
# If finishing a lane SHOULD end the goal, it needs (a) a reset path so the
# fact is not write-once and (b) a fallback behavior for a unit whose lane is
# done. Tracked in plans/E5.md; do not re-add the write without both.
