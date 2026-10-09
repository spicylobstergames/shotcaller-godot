extends Node

# Goap global class.
# This class is an autoload accessible globally.
# Access the autoload list in the Godot settings.
#
# Initializes the planner and exposes reusable GOAP/gameplay services.
# In your game, you might want to have different planners
# for different enemy/NPC types, and even change the set
# of actions at runtime.


var _action_planner = preload("res://goap/goap_system/planner.gd").new()
var _actions = preload("res://goap/game_logic/action_registry.gd").new()
var _goals = preload("res://goap/game_logic/goal_registry.gd").new()

@export var use_native_movement := true
@export var use_native_blocking := true
@export var use_native_pathfinding := true

var move
var navigation


func _ready():
	move = get_action("MoveAction")
	navigation = get_action("NavigateAction")
	_action_planner.set_actions(_actions.get_all_actions())


func get_action_planner():
	return _action_planner


func get_goal(goal):
	return _goals.get_goal(goal)


func get_action(action):
	return _actions.get_action(action)


func physics_process(units, delta):
	for unit in units:
		if unit.agent:
			unit.agent.process(delta)
