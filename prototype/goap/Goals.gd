extends Node

# self = Goap.Goals

# Lists all Goal contracts

var _goals = {
	"AttackEnemyGoal": preload("goals/attack_enemy.gd").new(),
	"NeedLumberGoal": preload("goals/need_lumber.gd").new(),
	"NeedSafetyGoal": preload("goals/need_safety.gd").new(),
	"RetreatGoal": preload("goals/retreat_goal.gd").new(),
	"SlayEnemiesGoal": preload("goals/slay_enemies.gd").new(),
	"CommandAttackEnemyGoal": preload("goals/command_attack_enemy.gd").new(),
	"CommandAttackGoal": preload("goals/command_attack.gd").new()
}

func get_goal(goal_name, default = null):
	return _goals.get(goal_name, default)


func set_goal(goal_name, value):
	_goals[goal_name] = value
