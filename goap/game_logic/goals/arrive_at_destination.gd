# =============================================================================
# GOAP-GUIDE: ArriveAtDestination - goal
#            (goap/game_logic/goals/arrive_at_destination.gd)
# =============================================================================
# Purpose   : Arrival SERVICE/LIBRARY goal -- path advancement and destination
#             collision checks. NOT a selectable goal.
# Plannable : NO - is_valid() hard-returns false (activation is disabled and
#             pinned by tests/unit/test_arrive_at_destination.gd).
# priority  : 3 (unused while is_valid() is false)
# desired   : {"arrived_at_destination": true}
# enter     : records has_path and clears arrived_at_destination.
# API       : is_at_destination(unit) and advance_path(unit) -- both are called
#             by Collisions.physics_process, not by the planner or the agent.
# advance_path : on a waypoint, pops the next one (Navigate.next). On the FINAL
#             arrival (empty path) it latches the arrival facts: has_path
#             false, has_destiny false, arrived_at_destination true, and stops
#             the unit. Those facts are the interface: actions drive their
#             arrival effects from perform() by reading them (PR #239
#             feedback -- no unit_arrived signal, no per-agent hook dispatch).
# Traps     : advance_path() takes the UNIT. Collisions passes the unit. Do
#             not re-enable activation without a golden re-record.
# See       : ARCHITECTURE.md "Arrival is collision-driven, not goal-driven";
#             tests/unit/test_arrival_dispatch.gd.
# =============================================================================

extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "ArriveAtDestination"


func is_valid(_agent) -> bool:
	return false
	#var unit = agent.get_unit()
	#var has_path = not unit.current_path.is_empty()
	#var is_moving_to_destination = (
		#unit.moves and unit.current_destiny != Vector2.ZERO
	#)
	#return has_path and is_moving_to_destination


func enter(agent):
	var unit = agent.get_unit()
	var has_path = not unit.current_path.is_empty()
	agent.set_state("has_path", has_path)
	agent.set_state("arrived_at_destination", false)


func priority(_agent) -> int:
	return 3


func get_desired_state(_agent) -> Dictionary:
	return {"arrived_at_destination": true}


func is_at_destination(unit) -> bool:
	var offset = 0
	if not unit.target:
		offset = WorldState.get_state("map").half_tile_size
	return unit.point_collision(unit.current_destiny, offset)


func advance_path(unit):
	# History sub-event (best effort: test doubles may not carry the record
	# API). Distinguishes an intermediate waypoint advance from the FINAL
	# arrival that latches arrived_at_destination.
	if unit.agent != null and unit.agent.has_method("record_event"):
		unit.agent.record_event(
			"arrive" if unit.current_path.is_empty() else "waypoint",
			unit.current_destiny
		)
	if not unit.current_path.is_empty():
		Goap.get_action("Navigate").next(unit)
	else:
		unit.current_path.clear()
		unit.agent.set_state("has_path", false)
		# The route is consumed: has_destiny must be cleared WITH has_path so
		# the planner cannot satisfy Move without a fresh Navigate.
		unit.agent.set_state("has_destiny", false)
		unit.agent.set_state("arrived_at_destination", true)
		Goap.get_action("Move").stop(unit)
