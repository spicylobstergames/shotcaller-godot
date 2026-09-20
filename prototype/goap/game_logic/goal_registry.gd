extends Node

# self = Goap.Goals
# Lists all goal contracts.
var _goals: Dictionary = {
	"AttackEnemiesGoal": preload("res://goap/game_logic/goals/attack_enemies.gd").new(),
	"FollowPathGoal": preload("res://goap/game_logic/goals/follow_path.gd").new(),
	"HelpFriendsGoal": preload("res://goap/game_logic/goals/help_friends.gd").new(),
	"NeedLumberGoal": preload("res://goap/game_logic/goals/need_lumber.gd").new(),
	"NeedSafetyGoal": preload("res://goap/game_logic/goals/need_safety.gd").new(),
	"PursueEnemiesGoal": preload("res://goap/game_logic/goals/pursue_enemies.gd").new(),
	"RetreatGoal": preload("res://goap/game_logic/goals/retreat_goal.gd").new(),
}


func get_goal(goal_name, default = null):
	if _goals.has(goal_name):
		return _goals[goal_name]
	return default


func set_goal(goal_name, value):
	_goals[goal_name] = value
