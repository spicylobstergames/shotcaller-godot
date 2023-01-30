extends "../Goal.gd"


func get_class(): return "FollowPathGoal"


func is_valid(agent) -> bool:
	var path = agent.get_state("current_path")
	var has_path = (path and not path.empty())
	agent.set_state("has_path", has_path)
	return has_path


func priority(agent) -> int:
	return 1 # higher if unit is further from lane


func get_desired_state(agent) -> Dictionary:
	return { 
		"close_to_path": true,
		"completed_path": true
	}
