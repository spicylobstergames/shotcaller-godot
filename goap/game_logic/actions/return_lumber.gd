# =============================================================================
# GOAP-GUIDE: ReturnLumber - action (goap/game_logic/actions/return_lumber.gd)
# =============================================================================
# Purpose   : Carry has_wood back to deliver_position, heal friendly buildings,
#             and satisfy the goal fact collected_wood.
# Plannable : yes - NeedLumber plan: GetLumber -> ReturnLumber.
# cost      : 5 (deliberately above GetLumber's 1)
# precond   : {"has_wood": true}
# effects   : {"collected_wood": true}
# enter     : Navigate.move(unit, deliver_position), with the Move fallback
#             when no route exists.
# perform   : false until the FINAL arrival (arrived_at_destination latched by
#             Collisions); then delivers ONCE (returning_wood latch: deliver,
#             clear has_wood, heal buildings) and completes.
# exit      : returning_wood = false.
# Traps     : the delivery used to ride an on_arrive hook that fired on EVERY
#             route waypoint -- multi-waypoint deliveries healed buildings
#             early and completed the plan before reaching deliver_position.
#             The arrival facts are the interface (Collisions ->
#             ArriveAtDestination.advance_path).
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "ReturnLumber"


func get_cost(_agent) -> int:
	return 5


func get_preconditions() -> Dictionary:
	return { "has_wood": true }


func get_effects() -> Dictionary:
	return { "collected_wood": true }


func perform(agent, _delta) -> bool:
	if agent.get_state("returning_wood", false):
		return true
	# Deliver exactly once, on the FINAL arrival (empty route), never on an
	# intermediate waypoint.
	if agent.get_state("arrived_at_destination", false):
		var unit = agent.get_unit()
		agent.set_state("returning_wood", true)
		agent.set_state("has_wood", false)
		# heal all player buildings
		for building in WorldState.get_state("all_buildings"):
			if unit.team == building.team:
					building.heal(building.regen)
		return true
	return false


func enter(agent):
	var unit = agent.get_unit()
	var deliver_position = agent.get_state("deliver_position")
	if deliver_position == null:
		return
	# Pathfind first; fall back to walking straight there when no route
	# exists (the established pattern in PursueEnemy/AttackEnemy).
	if not Goap.get_action("Navigate").move(unit, deliver_position):
		Goap.get_action("Move").move(unit, deliver_position)


func exit(agent):
	agent.set_state("returning_wood", false)
