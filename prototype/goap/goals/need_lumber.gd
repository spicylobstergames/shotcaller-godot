extends "../Goal.gd"

#class_name NeedLumberGoal

func get_class(): return "NeedLumberGoal"

func is_valid(agent) -> bool:
	return WorldState.get_state("is_game_active")


func priority(agent) -> int:
	return 10


func get_desired_state(agent) -> Dictionary:
	return {
		"collected_wood": true
	}
