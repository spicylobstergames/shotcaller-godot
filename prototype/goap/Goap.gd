extends Node

# Goap global class.
# This class is an autoload accessible globally.
# Access the autoload list in the Godot settings.
#
# Initializes a GoapActionPlanner with all the available actions.
# In your game, you might want to have different planners
# for different enemy/NPC types, and even change the set
# of actions at runtime.
#
# This example keeps things simple, creating only one planner
# with pre-defined actions.

var _action_planner = preload("ActionPlanner.gd").new()
var _actions = preload("Actions.gd").new()
var _goals = preload("Goals.gd").new()


func _ready():
	_action_planner.set_actions(_actions.get_all_actions())


func get_action_planner():
	return _action_planner


func get_goal(goal):
	return _goals.get_goal(goal)


func physics_process(units, delta):
	for unit in units:
		if unit.agent:
			unit.agent.process(delta)
