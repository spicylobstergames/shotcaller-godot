# =============================================================================
# GOAP-GUIDE: Recover - goal (goap/game_logic/goals/recover.gd)
# =============================================================================
# Purpose   : Retreat and heal back to fighting condition.
# priority  : 10
# desired   : {"ready_to_fight": true}
# is_valid  : should_retreat(unit) -- tactic-dependent: "retreat" always,
#             "defend" below 50% hp, "default" below 33% hp.
# enter     : ready_to_fight = false, is_retreating = true,
#             arrived_at_retreat = false.
# Traps     : deliberately has NO on_arrive hook. Arrival flows through
#             Collisions -> ArriveAtDestination.on_arrive(unit) and then
#             unit.on_arrive() -> RetreatAction.on_arrive. The old delegation
#             into ArriveAtDestination.on_arrive(agent) was removed (wrong
#             argument type + double path advance).
# See       : tests/unit/test_agent_tactic.gd.
# =============================================================================

extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "Recover"


func get_desired_state(_agent) -> Dictionary:
	return {"ready_to_fight": true}


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var is_low_hp = should_retreat(unit)
	return is_low_hp


func enter(agent):
	agent.set_state("ready_to_fight", false)
	agent.set_state("is_retreating", true)
	agent.set_state("arrived_at_retreat", false)


func priority(_agent) -> int:
	return 10


func should_retreat(unit) -> bool:
	var hp = Modifiers.get_value(unit, "hp")
	match unit.agent.get_state("tactic", "default"):
		"retreat":
			return true
		"defend":
			return unit.current_hp < hp / 2
		"default":
			return unit.current_hp < hp / 3
	return false


# NOTE: no on_arrive hook here. Arrival is dispatched by Collisions:
# ArriveAtDestination.on_arrive(unit) advances the path, then
# unit.on_arrive() -> Agent.on_arrive fires the current action hook
# (RetreatAction.on_arrive sets arrived_at_retreat, which this goal's plan
# needs). The old delegation passed the AGENT into
# ArriveAtDestination.on_arrive(unit), which double-advanced the path and
# read current_path off the agent once the arrival signal was wired.
