extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "ArriveAtDestination"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var has_path = not unit.current_path.is_empty()
	agent.set_state("has_path", has_path)
	var is_moving_to_destination = (
		unit.moves and unit.state == "move" and unit.current_destiny != Vector2.ZERO
	)
	if has_path or is_moving_to_destination:
		agent.set_state("arrived_at_destination", false)
		return true
	return false


func priority(_agent) -> int:
	return 1


func get_desired_state(_agent) -> Dictionary:
	return {"arrived_at_destination": true}


func is_at_destination(unit) -> bool:
	if not unit or not unit.agent:
		return false
	var offset = 0
	if not unit.target and not unit.agent.get_state("has_player_command"):
		offset = WorldState.get_state("map").half_tile_size
	return unit.point_collision(unit.current_destiny, offset)


func on_arrive(agent):
	var unit = agent.get_unit()
	if not unit.current_path.is_empty():
		Goap.navigation.next(unit)
	else:
		unit.current_path.clear()
		agent.set_state("has_path", false)
		agent.set_state("arrived_at_destination", true)
		Goap.move.end(unit)
