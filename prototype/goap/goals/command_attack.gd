extends "../Goal.gd"

#class_name CommandAttackGoal

func get_class(): return "CommandAttackGoal"

func is_valid(agent) -> bool:
	return agent.get_state("command_attack_point") != null


func priority(agent) -> int:
	return 1000


func get_desired_state(agent) -> Dictionary:
	return {
		"arrived_at_target": true
	}
