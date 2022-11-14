#
# Goal contract
#
extends Node

var _goals = {
	"AttackEnemyGoal": AttackEnemyGoal.new(),
	"NeedLumberGoal": NeedLumberGoal.new(),
	"NeedSafetyGoal": NeedSafetyGoal.new()
}

func get_goal(goal_name, default = null):
	return _goals.get(goal_name, default)
	
	
func set_goal(goal_name, value):
	_goals[goal_name] = value
