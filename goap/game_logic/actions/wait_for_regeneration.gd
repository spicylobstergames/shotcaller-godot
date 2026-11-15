# =============================================================================
# GOAP-GUIDE: WaitForRegeneration - action
#            (goap/game_logic/actions/wait_for_regeneration.gd)
# =============================================================================
# Purpose   : Hold at the retreat point until HP recovers past 90% of max.
# Plannable : yes - the second step of the Recover plan.
# is_valid  : unit.regen > 0
# cost      : 1
# precond   : {"arrived_at_retreat": true}
# effects   : {"ready_to_fight": true}
# enter     : Move.stop.
# perform   : true when current_hp > 90% of max hp.
# every_sec : unit.regenerate(+20).
# exit      : ready_to_fight = true.
# Traps     : pair with RetreatAction; without arrived_at_retreat the planner
#             cannot build this plan.
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"

const _wait_regen_bonus = 20


func get_class_name() -> String:
	return "WaitForRegeneration"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	#if unit.type == "leader": 
	#	print("arrived", agent.get_unit().display_name, agent.get_state("arrived_at_retreat", false)  )#and unit.regen > 0
	return unit.regen > 0


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {"arrived_at_retreat": true}


func get_effects() -> Dictionary:
	return {"ready_to_fight": true}


func enter(agent):
	Goap.get_action("Move").stop(agent.get_unit())


func perform(agent, _delta) -> bool:
	var unit = agent.get_unit()
	var hp = Modifiers.get_value(unit, "hp") * 0.9
	return unit.current_hp > hp


func on_every_second(agent):
	var unit = agent.get_unit()
	unit.regenerate(_wait_regen_bonus)


func exit(agent):
	agent.set_state("ready_to_fight", true)
