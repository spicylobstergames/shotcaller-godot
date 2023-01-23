extends Node

# This class is an Autoload accessible globally.
# It initialises a GoapActionPlanner with the available
# actions.
#
# In your game, you might want to have different planners
# for different enemy/npc types, and even change the set
# of actions in runtime.
#
# This example keeps things simple, creating only one planner
# with pre-defined actions.


# self = Goap


var _action_planner = preload("ActionPlanner.gd").new()
var _actions = preload("Actions.gd").new()
var _goals = preload("Goals.gd").new()

var agent = preload("../goap/Agent.gd")


func _ready():
	_action_planner.set_actions(_actions.get_all_actions())


func get_action_planner():
	return _action_planner


func get_goal(goal):
	return _goals.get_goal(goal)


func get_agent(unit):
	var new_agent = agent.new()
	new_agent.init(unit)
	return new_agent


func process(units, delta):
	for unit in units:
		if unit.agent._goals:
			unit.agent.process(delta)
