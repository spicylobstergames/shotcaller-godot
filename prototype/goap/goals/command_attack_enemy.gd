extends "../Goal.gd"

class_name CommandAttackEnemyGoal

func get_class(): return "CommandAttackEnemyGoal"

func is_valid(agent) -> bool:
	if agent.get_state("command_target_enemy") != null:
		return true
	return false

func priority(agent) -> int:
	return 1000


func get_desired_state(agent) -> Dictionary:
	return {
		"command_target_enemy": null
	}
