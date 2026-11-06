extends Node

# Stub autoload for Goap - provides minimal interface for Agent compilation
var _goals: Dictionary = {}
var _actions: Dictionary = {}
var _planner: Object

func get_goal(name: String, default = null) -> Variant:
	if _goals.has(name):
		return _goals[name]
	return default

func get_action(name: String) -> Variant:
	if _actions.has(name):
		return _actions[name]
	return null

func get_action_planner() -> Object:
	return _planner
