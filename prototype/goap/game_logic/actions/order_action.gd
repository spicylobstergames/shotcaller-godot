extends "res://goap/goap_system/action_contract.gd"


const PLAYER_ORDER_TYPES = ["move", "advance", "attack", "lane", "teleport", "stand"]


func get_class_name() -> String:
	return "OrderAction"


func is_valid(agent) -> bool:
	var order = agent.get_state("player_order")
	return order is Dictionary and not order.is_empty()


func get_effects() -> Dictionary:
	return {"player_order_complete": true}


func enter(agent):
	execute_player_order(agent)


func perform(agent, _delta) -> bool:
	return is_player_order_complete(agent)


func resume(unit):
	execute_player_order(unit.agent)


func exit(agent):
	var unit = agent.get_unit()
	if unit and not unit.dead:
		Goap.move.stop(unit)


func issue_player_order(unit, order_type: String, target: Vector2 = Vector2.ZERO) -> bool:
	if not unit or not unit.agent or order_type not in PLAYER_ORDER_TYPES:
		return false
	if not unit.is_controllable() or unit.dead:
		return false
	if unit.type != "leader":
		Goap.attack.set_target(unit, null)
		unit.start_control_delay()
		_execute_player_order(unit, order_type, target)
		return true
	var agent = unit.agent
	agent.clear_plan()
	Goap.move.stop(unit)
	unit.current_path.clear()
	agent.set_state("is_channeling", false)
	agent.set_state("player_order_id", agent.get_state("player_order_id", 0) + 1)
	agent.set_state("player_order", {"type": order_type, "target": target})
	agent.set_state("player_order_complete", false)
	agent.set_state("has_player_command", true)
	Goap.attack.set_target(unit, null)
	unit.start_control_delay()
	return true


func on_arrive(agent):
	var unit = agent.get_unit()
	match unit.after_arive:
		"conquer":
			Goap.get_action("ConquerAction").conquer_building(unit)
		"pray":
			Goap.get_action("PrayerAction").pray_in_church(unit)


func on_attack_end(agent):
	var unit = agent.get_unit()
	var order = agent.get_state("player_order", {})
	if order.get("type", "") == "attack":
		complete_player_order(agent)


func execute_player_order(agent):
	var unit = agent.get_unit()
	var order = agent.get_state("player_order", {})
	if unit == null or order.is_empty() or unit.dead:
		return
	if agent.get_state("is_stunned", false) or agent.get_state("stunned", false):
		return
	var target: Vector2 = order.get("target", Vector2.ZERO)
	_execute_player_order(unit, order.get("type", ""), target, agent)


func _execute_player_order(unit, order_type: String, target: Vector2, agent = null):
	match order_type:
		"move":
			if Goap.move.in_bounds(target):
				Goap.navigation.navigate_to(unit, target)
			elif agent:
				complete_player_order(agent)
		"advance":
			Goap.navigation.smart(unit, target)
		"attack":
			Goap.attack.point(unit, target)
		"lane":
			Goap.navigation.change_lane(unit, target)
		"teleport":
			Goap.move.teleport(unit, target)
		"stand":
			Goap.move.stop(unit)
			if agent:
				complete_player_order(agent)


func complete_player_order(agent):
	agent.erase_state("player_order")
	agent.set_state("player_order_complete", true)
	agent.set_state("has_player_command", false)


func cancel_player_order(agent):
	agent.clear_plan()
	agent.erase_state("player_order")
	agent.set_state("player_order_complete", false)
	agent.set_state("has_player_command", false)


func is_player_order_complete(agent) -> bool:
	var order = agent.get_state("player_order", {})
	if order.is_empty():
		return true
	var unit = agent.get_unit()
	if unit == null:
		return true
	if unit.dead:
		cancel_player_order(agent)
		return true
	if agent.get_state("is_stunned", false) or agent.get_state("stunned", false):
		return false
	if agent.get_state("is_channeling", false):
		return false
	if agent.get_state("player_order_complete", false):
		complete_player_order(agent)
		return true

	var is_complete := false
	match order.get("type", ""):
		"move", "advance", "lane":
			is_complete = (
				unit.state == "idle"
				and unit.current_path.is_empty()
				and unit.current_destiny == Vector2.ZERO
				and unit.final_destiny == Vector2.ZERO
			)
	if is_complete:
		complete_player_order(agent)
	return is_complete
