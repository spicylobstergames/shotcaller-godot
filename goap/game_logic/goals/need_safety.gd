# =============================================================================
# GOAP-GUIDE: NeedSafety - goal (goap/game_logic/goals/need_safety.gd)
# =============================================================================
# Purpose   : Hide from nearby enemies.
# priority  : 10 (ties with Recover; on a tie the earlier-registered goal wins)
# desired   : {"is_threatened": false}   (produced by Hide)
# is_valid  : any enemy in sight; writes is_threatened on every evaluation.
# Traps     : this goal is only in the lumberjack's goals_list, and Hide needs
#             deliver_position (set at spawn). See the goal's note in
#             docs/ai/world-state.md.
# =============================================================================

extends "res://goap/goap_system/goal_contract.gd"


# hide behavior


func get_class_name(): return "NeedSafety"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_sight({"team": unit.opponent_team()})
	agent.set_state("is_threatened", not enemies.is_empty())
	return not enemies.is_empty()


func priority(_agent) -> int:
	return 10


func get_desired_state(_agent) -> Dictionary:
	return { "is_threatened": false }
