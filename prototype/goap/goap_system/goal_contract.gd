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
