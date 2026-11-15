# GOAP-GUIDE: MyGoal - goal (goap/game_logic/goals/my_goal.gd)
# =============================================================================
# New goal scaffold (from docs/ai/templates/goal_template.gd).
# Replace every TODO, then follow docs/ai/adding-behavior.md.
# =============================================================================
# Purpose   : TODO one line: what the unit wants.
# priority  : TODO integer; higher wins (strict >, earlier goal wins a tie).
# desired   : TODO {"fact": value} -- must be producible by some action's
#             effects; an empty desired state returns an empty plan.
# is_valid  : TODO eligibility. Keep it PURE; the documented exceptions
#             (EnemyDefeated/FriendsSafe/NeedSafety) reset stale success facts
#             here on purpose.
# enter     : TODO (runs on goal change; the planner runs BEFORE this).
# Traps     : TODO stale-fact risk, scene availability, etc.
# See       : docs/ai/adding-behavior.md; docs/ai/world-state.md.
# =============================================================================

extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "MyGoal"


func is_valid(_agent) -> bool:
	# TODO: return false until implemented.
	return false


func priority(_agent) -> int:
	return 1


func get_desired_state(_agent) -> Dictionary:
	return {}


func enter(_agent) -> void:
	pass


func exit(_agent) -> void:
	pass
