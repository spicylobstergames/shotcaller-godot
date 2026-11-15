# =============================================================================
# GOAP-GUIDE: ChooseTactics - action (goap/game_logic/actions/choose_tactics.gd)
# =============================================================================
# Purpose   : DEAD STUB. No behavior, no callers.
# Plannable : no - is_valid() hard-returns false.
# is_valid  : false
# cost      : 1 (default)
# precond   : {}
# effects   : {}
# Traps     : Extends Node instead of action_contract.gd (contract violation)
#             and is referenced only by action_registry.gd. Do NOT copy it as a
#             template; it is slated for deletion (IMPROVEMENT_PLAN.md Track E1).
# =============================================================================

extends Node


func get_class_name() -> String:
	return "ChooseTactics"

func is_valid(_agent) -> bool:
	return false


# Action Cost. This is a function so it handles situational costs, when the world
# state is considered when calculating the cost.
func get_cost(_agent) -> int:
	return 1


# Action requirements.
# Example: { "has_axe": true }
func get_preconditions() -> Dictionary:
	return {}


# What conditions this action satisfies
# Example: { "has_wood": true }
func get_effects() -> Dictionary:
	return {}


# Runs once when the action starts
func enter(_agent):
	pass


# Action implementation called on every loop.
# "agent" is the controller of the NPC
# "delta" is the time in seconds since last loop.
#
# Returns true when the task is complete.
# Example: return agent.get_state("has_wood")
func perform(_agent, _delta) -> bool:
	return false


# Runs once when the action ends
func exit(_agent) :
	pass
