# =============================================================================
# GOAP-GUIDE: NeedLumber - goal (goap/game_logic/goals/need_lumber.gd)
# =============================================================================
# Purpose   : Lumberjack loop -- collect wood and deliver it, forever.
# priority  : 1 (lowest; WalkLane at 2 outranks it, but a lumberjack has an
#             empty lane so WalkLane is invalid for it)
# desired   : {"collected_wood": true}
# is_valid  : not is_running and not is_hiding.
# Traps     : collected_wood is a PLANNING fact produced by
#             ReturnLumber.get_effects(); nothing ever sets it at runtime, so
#             the plan legitimately repeats (that is the gather loop).
# See       : docs/ai/world-state.md (collected_wood).
# =============================================================================

extends "res://goap/goap_system/goal_contract.gd"


func get_class_name(): return "NeedLumber"


func is_valid(agent) -> bool:
	return not agent.get_state("is_running") and not agent.get_state("is_hiding")


func priority(_agent) -> int:
	return 1


func get_desired_state(_agent) -> Dictionary:
	return { "collected_wood": true }
