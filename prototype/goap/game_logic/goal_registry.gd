extends Node

# self = Goap.Goals

# Lists all goal contracts.
var _goals: Dictionary = {
	"AttackEnemies": preload("res://goap/game_logic/goals/attack_enemies.gd").new(),
	"FollowPath": preload("res://goap/game_logic/goals/follow_path.gd").new(),
	"HelpFriends": preload("res://goap/game_logic/goals/help_friends.gd").new(),
	"NeedLumber": preload("res://goap/game_logic/goals/need_lumber.gd").new(),
	"NeedSafety": preload("res://goap/game_logic/goals/need_safety.gd").new(),
	"PursueEnemies": preload("res://goap/game_logic/goals/pursue_enemies.gd").new(),
	"Retreat": preload("res://goap/game_logic/goals/retreat_goal.gd").new(),
	"WaitOut": preload("res://goap/game_logic/goals/wait_out.gd").new()
}


func get_goal(goal_name, default = null):
	if _goals.has(goal_name):
		return _goals[goal_name]
	return default


func set_goal(goal_name, value):
	_goals[goal_name] = value
