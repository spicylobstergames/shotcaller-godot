extends Node

# self = Goap.Goals

# Lists all goal contracts.
var _goals: Dictionary = {
	"ArriveAtDestination": preload("res://goap/game_logic/goals/arrive_at_destination.gd").new(),
	"EnemyDefeated": preload("res://goap/game_logic/goals/enemy_defeated.gd").new(),
	"FriendsSafe": preload("res://goap/game_logic/goals/friends_safe.gd").new(),
	"NeedLumber": preload("res://goap/game_logic/goals/need_lumber.gd").new(),
	"NeedSafety": preload("res://goap/game_logic/goals/need_safety.gd").new(),
	"ObeyPlayer": preload("res://goap/game_logic/goals/obey_player.gd").new(),
	"Recover": preload("res://goap/game_logic/goals/recover.gd").new()
}


func get_goal(goal_name, default = null):
	if _goals.has(goal_name):
		return _goals[goal_name]
	return default


func set_goal(goal_name, value):
	_goals[goal_name] = value
