extends "../Action.gd"


func get_class(): return "FollowPath"


func is_valid(agent) -> bool:
	return agent.get_state("has_path")


func get_cost(agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return { 
		"close_to_path": true,
		"completed_path": true
	}


func perform(agent, delta) -> bool:
	return agent.get_state("completed_path")


func enter(agent):
	var unit = agent.get_unit()
	var path = agent.get_state("current_path")
	var new_path = unit.cut_path(path)
	if not new_path.empty():
		Behavior.follow.path(unit, new_path)


func on_arrive(agent):
	var unit = agent.get_unit()
	Behavior.follow.next(unit)
#	else:
#		agent.set_state("completed_path", true)

