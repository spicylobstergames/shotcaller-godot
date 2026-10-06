extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "ArriveAtDestination"


func is_valid(agent) -> bool:
	var has_path = not agent.get_unit().current_path.is_empty()
	agent.set_state("has_path", has_path)
	if has_path:
		agent.set_state("arrived_at_destination", false)
	return has_path


func priority(_agent) -> int:
	return 1


func get_desired_state(_agent) -> Dictionary:
	return {"arrived_at_destination": true}
