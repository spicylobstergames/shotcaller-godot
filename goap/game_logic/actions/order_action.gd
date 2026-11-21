# =============================================================================
# GOAP-GUIDE: Order - action (goap/game_logic/actions/order_action.gd)
# =============================================================================
# Purpose   : Execute the player's current order (move/advance/attack/lane/
#             teleport/stand) through the ObeyPlayer goal.
# Plannable : yes - ObeyPlayer({player_order_complete: true}) -> Order.
# is_valid  : player_order is a non-empty Dictionary.
# precond   : {} (default)
# effects   : {"player_order_complete": true}
# enter     : execute_player_order.
# perform   : dispatches the after_arive follow-up (conquer/pray) ONCE on the
#             FINAL arrival, then is_player_order_complete -- for move orders
#             that means the unit is idle with no path and no destinies; a
#             dead unit cancels instead.
# resume    : re-executes after a stun ends.
# exit      : Move.stop.
# API       : issue_player_order(unit, type, point) is the UI entry point.
# Writes    : player_order, player_order_complete, has_player_command,
#             after_arive, is_channeling, player_order_id.
# Traps     : "after_arive" is a misspelled key shared with the arrival
#             follow-up (Track D). The follow-up used to ride an on_arrive
#             hook that fired on EVERY route waypoint; it now dispatches only
#             on the final arrival (arrived_at_destination), from perform().
#             Non-leaders execute orders immediately and bypass the goal.
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"


const PLAYER_ORDER_TYPES = ["move", "advance", "attack", "lane", "teleport", "stand"]


func get_class_name() -> String:
	return "Order"


func is_valid(agent) -> bool:
	var order = agent.get_state("player_order")
	return order is Dictionary and not order.is_empty()


func get_effects() -> Dictionary:
	return {"player_order_complete": true}


func enter(agent):
	execute_player_order(agent)


func perform(agent, _delta) -> bool:
	_dispatch_arrival(agent)
	return is_player_order_complete(agent)


# Conquer/pray run when the unit reaches its front-door tile: dispatch the
# after_arive follow-up exactly once, on the FINAL arrival (the facts latched
# by Collisions -> ArriveAtDestination.advance_path). The old on_arrive hook
# fired on every route waypoint, so multi-waypoint orders could conquer/pray
# before reaching the building.
func _dispatch_arrival(agent):
	if not agent.get_state("arrived_at_destination", false):
		return
	var unit = agent.get_unit()
	match agent.get_state("after_arive"):
		"conquer":
			agent.set_state("after_arive", "stop")
			Goap.get_action("Conquer").conquer_building(unit)
		"pray":
			agent.set_state("after_arive", "stop")
			Goap.get_action("Pray").pray_in_church(unit)


func resume(unit):
	execute_player_order(unit.agent)


func exit(agent):
	var unit = agent.get_unit()
	if unit and not unit.dead:
		Goap.get_action("Move").stop(unit)


func issue_player_order(unit, order_type: String, point: Vector2 = Vector2.ZERO) -> bool:
	var target = get_order_point(unit, point)
	if not unit or not unit.agent or order_type not in PLAYER_ORDER_TYPES:
		return false
	if not unit.is_controllable() or unit.dead:
		return false
	if unit.type != "leader":
		unit.agent.set_state("target", null)
		unit.start_control_delay()
		_execute_player_order(unit, order_type, target)
		return true
	var agent = unit.agent
	agent.clear_plan()
	Goap.get_action("Move").stop(unit)
	unit.current_path.clear()
	agent.set_state("is_channeling", false)
	agent.set_state("player_order_id", agent.get_state("player_order_id", 0) + 1)
	agent.set_state("player_order", {"type": order_type, "target": target})
	agent.set_state("player_order_complete", false)
	agent.set_state("has_player_command", true)
	agent.set_state("target", null)
	unit.start_control_delay()
	return true


func get_order_point(unit, point):
	unit.agent.set_state("after_arive", "stop")
	if point:
		var building = Utils.get_building(point)
		if building:
			var opponent = unit.opponent_team()
			match building.team:
				# attack enemy buildings
				opponent: unit.agent.set_state("after_arive", "attack")
				# conquer neutral buildings
				"neutral":
					point = front_door_point(building)
					unit.agent.set_state("after_arive", "conquer")
				unit.team:
					point = front_door_point(building)
					# stop next to friendly buildings
					unit.agent.set_state("after_arive", "stop")
					# pray on friendly churches
					if building.display_name == "church":
						unit.agent.set_state("after_arive", "pray")

		return point


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
			if Goap.get_action("Move").in_bounds(target):
				Goap.get_action("Navigate").move(unit, target)
			elif agent:
				complete_player_order(agent)
		"advance":
			Goap.get_action("Navigate").point(unit, target)
		"attack":
			Goap.get_action("AttackEnemy").point(unit, target)
		"lane":
			Goap.get_goal("WalkLane").change_lane(unit, target)
		"teleport":
			Goap.get_action("Move").teleport(unit, target)
		"stand":
			Goap.get_action("Move").stop(unit)
			if agent:
				complete_player_order(agent)


func is_player_order_complete(agent) -> bool:
	var order = agent.get_state("player_order", {})
	if order.is_empty():
		return true
	var unit = agent.get_unit()
	if unit.dead:
		cancel_player_order(agent)
		return true
	if (agent.get_state("is_stunned", false) or
		agent.get_state("stunned", false) or
		agent.get_state("is_channeling", false)):
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



func front_door_point(building):
	var point = building.global_position
	point.y += WorldState.get_state("map").tile_size/2
	return point
	
	
func cancel_player_order(agent):
	agent.cancel_player_order()


func complete_player_order(agent):
	agent.erase_state("player_order")
	agent.set_state("has_player_command", false)
