extends "res://goap/goap_system/goal_contract.gd"

const ORDER_PRIORITY := 1000000


func get_class_name():
	return "ObeyPlayer"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var order = agent.get_state("player_order")
	return (
		unit.type == "leader"
		and unit.is_controllable()
		and not unit.dead
		and order is Dictionary
		and not order.is_empty()
	)


func priority(_agent) -> int:
	return ORDER_PRIORITY


func get_desired_state(_agent) -> Dictionary:
	return {"player_order_complete": true}
