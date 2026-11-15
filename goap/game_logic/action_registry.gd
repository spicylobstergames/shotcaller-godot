# =============================================================================
# GOAP-GUIDE: Action registry (goap/game_logic/action_registry.gd)
# =============================================================================
# Creates every action ONCE as a shared singleton. Never store per-unit mutable
# state on an instance (the one documented exception is team-scoped:
# Taxes.player_tax / enemy_tax).
# Plannable (real preconditions/effects): Move, Navigate, ChooseTarget,
#   PursueEnemy, AttackEnemy, Retreat, WaitForRegeneration, Hide, HelpFriend,
#   GetLumber, ReturnLumber.
# Service / signal-driven (never selected): RangeAttack, MeleeAttack, Order,
#   Taxes, Mine, Conquer, Pray, ChooseTactics (dead -- Track E1).
# get_action() accepts an int index or a class-name String.
# Adding an action: create the script, add it here, and keep the registry count
# in tests/unit/test_planner_real_actions.gd in sync.
# =============================================================================

extends Node

# Lists all actions.
var _actions: Array = [
	preload("res://goap/game_logic/actions/attack_enemy.gd").new(),
	preload("res://goap/game_logic/actions/choose_tactics.gd").new(),
	preload("res://goap/game_logic/actions/choose_target.gd").new(),
	preload("res://goap/game_logic/actions/conquer_action.gd").new(),
	preload("res://goap/game_logic/actions/get_lumber.gd").new(),
	preload("res://goap/game_logic/actions/help_friend.gd").new(),
	preload("res://goap/game_logic/actions/hide.gd").new(),
	preload("res://goap/game_logic/actions/melee_attack.gd").new(),
	preload("res://goap/game_logic/actions/mine_action.gd").new(),
	preload("res://goap/game_logic/actions/move_action.gd").new(),
	preload("res://goap/game_logic/actions/navigate_action.gd").new(),
	preload("res://goap/game_logic/actions/order_action.gd").new(),
	preload("res://goap/game_logic/actions/prayer_action.gd").new(),
	preload("res://goap/game_logic/actions/pursue_enemy.gd").new(),
	preload("res://goap/game_logic/actions/range_attack.gd").new(),
	preload("res://goap/game_logic/actions/retreat_action.gd").new(),
	preload("res://goap/game_logic/actions/return_lumber.gd").new(),
	preload("res://goap/game_logic/actions/taxes_action.gd").new(),
	preload("res://goap/game_logic/actions/wait_for_regeneration.gd").new(),
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
