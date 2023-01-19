extends Node

# self = Goap.Goals

# Lists all Goal contracts

var _goals = {
	"AttackEnemyGoal": AttackEnemyGoal.new(),
	"NeedLumberGoal": NeedLumberGoal.new(),
	"NeedSafetyGoal": NeedSafetyGoal.new(),
	"RetreatGoal": RetreatGoal.new(),
	"SlayEnemiesGoal": SlayEnemiesGoal.new(),
	"CommandAttackEnemyGoal": CommandAttackEnemyGoal.new(),
	"CommandAttackGoal": CommandAttackGoal.new()
}

func get_goal(goal_name, default = null):
	return _goals.get(goal_name, default)


func set_goal(goal_name, value):
	_goals[goal_name] = value
