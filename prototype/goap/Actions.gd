extends Node

# Lists all actions.
var _actions: Array = [
	preload("actions/attack_enemy.gd").new(),
	preload("actions/follow_path.gd").new(),
	preload("actions/get_lumber.gd").new(),
	preload("actions/help_friend.gd").new(),
	preload("actions/hide.gd").new(),
	preload("actions/pursue_enemy.gd").new(),
	preload("actions/retreat_action.gd").new(),
	preload("actions/return_lumber.gd").new(),
	preload("actions/wait_out.gd").new(),
]


func get_all_actions() -> Array:
	return _actions


func get_action(action_name, default = null):
	if action_name is int:
		if action_name >= 0 and action_name < _actions.size():
			return _actions[action_name]
		return default

	if action_name is String:
		for action in _actions:
			if action.has_method("get_class_name") and action.get_class_name() == action_name:
				return action
			if action.has_method("get_name") and action.get_name() == action_name:
				return action
		return default

	return default


func set_action(action_name, value):
	_actions[action_name] = value
