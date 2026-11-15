# =============================================================================
# GOAP-GUIDE: Goal contract (goap/goap_system/goal_contract.gd)
# =============================================================================
# Every active goal extends this file.
#   is_valid(agent)          -> may this goal be chosen right now?
#   priority(agent)          -> higher wins; strict >, so the first-registered
#                               goal wins a tie
#   get_desired_state(agent) -> the facts the planner must achieve
#   enter / exit(agent)      -> called by the Agent on goal change; the planner
#                               ignores them
# is_valid() runs for every goal of every unit on that unit's staggered turn
# (~8.6 Hz). It SHOULD be pure; the three documented exceptions (EnemyDefeated,
# FriendsSafe, NeedSafety) reset stale success facts there on purpose -- without
# that reset the planner sees the desired state as already satisfied and
# returns an empty plan.
# See: ARCHITECTURE.md "State facts"; docs/ai/adding-behavior.md.
# =============================================================================

extends Node

# self = Goap.Goal

# Goal contract
#
# This indicates if the goal should be considered or not.
# Sometimes instead of changing the priority, it is easier to
# not even consider the goal. i.e. Ignore combat related goals
# when there are not enemies nearby.
func is_valid(_agent) -> bool:
	return true


# Returns goals priority. This priority can be dynamic.
func priority(_agent) -> int:
	return 1


# Plan's desired state. This is usually referred as desired world
# state, but it doesn't need to match the raw world state.
#
# For example, in your world state you may store "hunger" as a number, but inside your
# goap you can deal with it as "is_hungry".
func get_desired_state(_agent) -> Dictionary:
	return {}


func enter(_agent):
	pass


func exit(_agent):
	pass
