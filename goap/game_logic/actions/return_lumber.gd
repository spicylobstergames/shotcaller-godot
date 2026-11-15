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
# perform   : returns returning_wood.
# on_arrive : returning_wood = true; has_wood = false; heals every friendly
#             building by its regen.
# exit      : returning_wood = false.
# Traps     : previously assigned set_state()'s null return to a nonexistent
#             unit property and never moved; keep the navigation explicit.
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
	return agent.get_state("returning_wood", false)


func enter(agent):
	var unit = agent.get_unit()
	var deliver_position = agent.get_state("deliver_position")
	if deliver_position == null:
		return
	# Pathfind first; fall back to walking straight there when no route
	# exists (the established pattern in PursueEnemy/AttackEnemy).
	if not Goap.get_action("Navigate").move(unit, deliver_position):
		Goap.get_action("Move").move(unit, deliver_position)


func on_arrive(agent):
	var unit = agent.get_unit()
	agent.set_state("returning_wood", true)
	agent.set_state("has_wood", false)
	# heal all player buildings
	for building in WorldState.get_state("all_buildings"):
		if unit.team == building.team:
				building.heal(building.regen)


func exit(agent):
	agent.set_state("returning_wood", false)
