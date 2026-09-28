extends "res://goap/goap_system/action_contract.gd"


func get_class_name():
	return "ObeyPlayer"


func is_valid(agent) -> bool:
	var order = agent.get_state("player_order")
	return order is Dictionary and not order.is_empty()


func get_effects() -> Dictionary:
	return {"player_order_complete": true}


func enter(agent):
	Goap.orders.execute_player_order(agent)


func perform(agent, _delta) -> bool:
	return Goap.orders.is_player_order_complete(agent)


func resume(unit):
	Goap.orders.execute_player_order(unit.agent)


func exit(agent):
	var unit = agent.get_unit()
	if unit and not unit.dead:
		Goap.move.stop(unit)