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
# Traps     : deliberately has NO arrival hook. Arrival is a GOAP state
#             transition: Collisions -> ArriveAtDestination.advance_path
#             latches arrived_at_destination, and RetreatAction.perform reads
#             it to set arrived_at_retreat. The old delegation into
#             ArriveAtDestination.on_arrive(agent) was removed (wrong
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
	if is_low_hp:
		# Maintain the fact BEFORE planning. Recover.enter() runs AFTER
		# get_plan(), so with ready_to_fight still true the desired state
		# looked satisfied and the planner returned an EMPTY plan — the unit
		# never actually retreated.
		agent.set_state("ready_to_fight", false)
	else:
		# Stale-fact maintenance (same pattern as EnemyDefeated/FriendsSafe).
		# RetreatAction.exit() is the only other place that clears
		# is_retreating, and it never runs when the Recover plan is empty.
		# Left set, is_retreating blocks WalkLane (its gate) and
		# ready_to_fight=false blocks EnemyDefeated — the unit ends at
		# goal=null and stands still forever.
		agent.set_state("is_retreating", false)
		agent.set_state("ready_to_fight", true)
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


# NOTE: no arrival hook here. Arrival is a GOAP state transition dispatched by
# Collisions: ArriveAtDestination.advance_path(unit) advances the path or
# latches the final-arrival facts; RetreatAction.perform reads
# arrived_at_destination and sets arrived_at_retreat, which this goal's plan
# needs. The old delegation passed the AGENT into
# ArriveAtDestination.on_arrive(unit), which double-advanced the path.
