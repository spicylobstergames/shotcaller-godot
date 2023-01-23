extends "../Goal.gd"

#class_name AttackEnemyGoal

func get_class(): return "AttackEnemyGoal"

func is_valid(agent) -> bool:
	return WorldState.get_state("is_game_active")


func priority(agent) -> int:
	return 10


func get_desired_state(agent) -> Dictionary:
	return {
		"is_game_active": false
	}
