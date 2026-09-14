extends Node

# self = Goap.Goals
# Lists all goal contracts.
var _goals: Dictionary = {
	"AttackEnemiesGoal": preload("goals/attack_enemies.gd").new(),
	"FollowPathGoal": preload("goals/follow_path.gd").new(),
	"HelpFriendsGoal": preload("goals/help_friends.gd").new(),
	"NeedLumberGoal": preload("goals/need_lumber.gd").new(),
	"NeedSafetyGoal": preload("goals/need_safety.gd").new(),
	"PursueEnemiesGoal": preload("goals/pursue_enemies.gd").new(),
	"RetreatGoal": preload("goals/retreat_goal.gd").new(),
}


func get_goal(goal_name, default = null):
	if _goals.has(goal_name):
		return _goals[goal_name]
	return default


func set_goal(goal_name, value):
	_goals[goal_name] = value
