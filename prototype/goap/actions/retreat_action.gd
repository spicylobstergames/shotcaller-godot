extends "../Action.gd"


func get_class_name(): return "RetreatAction"


func get_cost(_agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return { "arrived_at_retreat": true }


func perform(agent, _delta) -> bool:
	return agent.get_state("arrived_at_retreat")


func enter(agent):
	var unit = agent.get_unit()
	unit.agent.set_state("is_retreating", true)
	# clear previous path and targets
	unit.current_path = []
	Behavior.attack.set_target(unit, null)
	# update lane data in case of lane change
	var order
	if unit.team == WorldState.game.player_team:
		if unit.name in Behavior.orders.player_leaders_orders:
			order = Behavior.orders.player_leaders_orders[unit.name]
	elif unit.team == WorldState.game.enemy_team:
		if unit.name in Behavior.orders.enemy_leaders_orders:
			order = Behavior.orders.enemy_leaders_orders[unit.name]
	Behavior.orders.set_leader(unit, order)
	var lane = agent.get_state("lane")
	var path = WorldState.lanes[lane].duplicate()
	if unit.team == "red": path.invert()
	Behavior.move.point(unit, path[0])


func on_arrive(agent):
	agent.set_state("arrived_at_retreat", true)
