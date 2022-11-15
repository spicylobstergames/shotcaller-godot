extends GoapGoal

class_name NeedSafetyGoal

func get_class(): return "NeedSafetyGoal"

func priority(agent) -> int:
		return 50


func get_desired_state(agent) -> Dictionary:
	return {
		"is_threatened": false
	}

func is_valid(agent) -> bool:
		return agent.get_state("is_threatened")
