extends Node

# Lists all Actions

var _actions = [
	preload("actions/advance_on_enemy.gd").new(),
	preload("actions/get_lumber.gd").new(),
	preload("actions/return_lumber.gd").new(),
	preload("actions/attack_enemy.gd").new(),
	preload("actions/retreat_action.gd").new(),
	preload("actions/wait_out.gd").new(),
	preload("actions/hide.gd").new(),
	preload("actions/advance_on_position.gd").new()
]

func get_all_actions():
	return _actions


func get_action(action_name, default = null):
	return _actions.get(action_name, default)


func set_action(action_name, value):
	_actions[action_name] = value
