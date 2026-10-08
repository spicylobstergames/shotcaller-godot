extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "FollowPath"


func is_valid(agent) -> bool:
	return agent.get_unit().moves and agent.get_state("has_path", false)


func get_cost(_agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return {"arrived_at_destination": true}


func perform(agent, _delta) -> bool:
	return agent.get_state("arrived_at_destination", false)


func enter(agent):
	var unit = agent.get_unit()
	var path = unit.current_path
	var new_path = unit.cut_path(path)
	agent.set_state("arrived_at_destination", false)
	if not new_path.is_empty():
		Goap.navigation.start(unit, new_path)
	else:
		agent.set_state("arrived_at_destination", true)


func on_arrive(agent):
	if agent.get_unit().current_path.is_empty():
		agent.set_state("arrived_at_destination", true)


func on_animation_end(_agent):
	# var limit = Goap.follow.max_lane_distance
	# var distance = distance_to_lane( agent.get_unit() )
	# agent.set_state("close_to_path", distance < limit)
	pass
