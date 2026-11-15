# =============================================================================
# GOAP-GUIDE: Action contract (goap/goap_system/action_contract.gd)
# =============================================================================
# Every PLANNABLE action extends this file and overrides the methods below.
# Planning reads is_valid / get_cost / get_preconditions / get_effects;
# execution calls enter / perform / exit.
# Defaults here are deliberately permissive:
#   is_valid              -> true   (actions opt OUT; a false default once
#                                    silently unplanned nine shipped actions)
#   get_cost              -> 1
#   get_preconditions     -> {}
#   get_effects           -> {}
#   perform               -> false  (runs forever unless overridden)
# get_class_name() is NOT declared here; each action defines it for the
# registry and Goap.get_action(name).
# SERVICE actions (RangeAttack, MeleeAttack, Taxes, Mine, Conquer, Pray,
# Order, ChooseTactics) also extend this file but are never selected by the
# planner; they are called directly or from signals.
# See: ARCHITECTURE.md "Contracts and registries"; docs/ai/adding-behavior.md.
# =============================================================================

extends Node

# self = Goap.Action

# Action Contract


# This indicates if the action should be considered or not.
#
# Currently I'm using this method only during planning, but it could
# also be used during execution to abort the plan in case the world state
# does not allow this action anymore.
#
# Default is true: actions are plannable unless they opt out. A default of
# false silently unplans every action that does not override this (nine
# production actions — melee/range attack, hide, taxes, etc. — were dead in
# the planner after the default was flipped; caught by
# test_planner_real_actions.gd). ChooseTarget is the documented always-false
# exception and overrides this itself.
func is_valid(_agent) -> bool:
	return true


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
	return false # is_step_complete


# Runs once when the action ends
func exit(_agent) :
	pass
