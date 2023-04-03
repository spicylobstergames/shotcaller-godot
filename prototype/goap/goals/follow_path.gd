extends "../Goal.gd"


func get_class(): return "FollowPathGoal"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var path = unit.current_path
	var has_path = not path.is_empty()
	agent.set_state("has_path", has_path)
	return has_path


func priority(agent) -> int:
	return 1 # higher if unit is further from lane


func get_desired_state(agent) -> Dictionary:
	return { 
		"close_to_path": true,
		"completed_path": true
	}
