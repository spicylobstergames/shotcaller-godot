extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "ArriveAtDestination"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var has_path = not unit.current_path.is_empty()
	var is_moving_to_destination = (
		unit.moves and unit.current_destiny != Vector2.ZERO
	)
	return has_path or is_moving_to_destination


func enter(agent):
	var unit = agent.get_unit()
	var has_path = not unit.current_path.is_empty()
	agent.set_state("has_path", has_path)
	agent.set_state("arrived_at_destination", false)


func priority(_agent) -> int:
	return 3


func get_desired_state(_agent) -> Dictionary:
	return {"arrived_at_destination": true}


func is_at_destination(unit) -> bool:
	var offset = 0
	if not unit.target:
		offset = WorldState.get_state("map").half_tile_size
	return unit.point_collision(unit.current_destiny, offset)


func on_arrive(agent):
	var unit = agent.get_unit()
	if not unit.current_path.is_empty():
		Goap.get_action("Navigate").next(unit)
	else:
		unit.current_path.clear()
		agent.set_state("has_path", false)
		agent.set_state("arrived_at_destination", true)
		Goap.get_action("Move").stop(unit)
	
