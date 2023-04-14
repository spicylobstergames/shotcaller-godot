extends "../Action.gd"


func get_class_name(): return "FollowPath"


func is_valid(agent) -> bool:
	return agent.get_unit().moves


func get_cost(_agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return { 
		"close_to_path": true,
		"completed_path": true
	}


func perform(agent, _delta) -> bool:
	return agent.get_state("completed_path")


func enter(agent):
	var unit = agent.get_unit()
	var path = unit.current_path
	var new_path = unit.cut_path(path)
	if not new_path.is_empty():
		Behavior.path.start(Callable(unit,new_path))


func on_arrive(agent):
	var unit = agent.get_unit()
	if agent.get_state("has_path"):
		Behavior.path.next(unit)
	else:
		agent.set_state("completed_path", true)


func on_animation_end(_agent):
	# var limit = Behavior.follow.max_lane_distance
	# var distance = distance_to_lane( agent.get_unit() )
	# agent.set_state("close_to_path", distance < limit)
	pass
