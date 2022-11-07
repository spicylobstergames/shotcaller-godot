#
# Action Contract
#
extends Node

class_name GoapAction


#
# This indicates if the action should be considered or not.
#
# Currently I'm using this method only during planning, but it could
# also be used during execution to abort the plan in case the world state
# does not allow this action anymore.
#
func is_valid() -> bool:
	return true


#
# Action Cost. This is a function so it handles situational costs, when the world
# state is considered when calculating the cost.
#
# Check "./actions/chop_tree.gd" for a situational cost example.
#
func get_cost(_blackboard) -> int:
	return 1000

#
# Action requirements.
# Example:
# {
#	 "has_wood": true
# }
#
func get_preconditions() -> Dictionary:
	return {}


#
# What conditions this action satisfies
#
# Example:
# {
#	 "has_wood": true
# }
func get_effects() -> Dictionary:
	return {}


#
# Action implementation called on every loop.
# "agent" is the controller of the NPC
# "delta" is the time in seconds since last loop.
#
# Returns true when the task is complete.
#
#
func perform(_agent, _delta) -> bool:
	return false

func enter(_agent):
	pass
	
func exit(_agent) :
	pass
func on_every_second(_agent) :
	pass
func on_arrive(_agent):
	pass
