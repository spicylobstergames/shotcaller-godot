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
	Goap.attack.set_target(unit, null)
	# update lane data in case of lane change
	var order
	if unit.team == WorldState.get_state("player_team"):
		if unit.name in Goap.orders.player_leaders_orders:
			order = Goap.orders.player_leaders_orders[unit.name]
	elif unit.team == WorldState.get_state("enemy_team"):
		if unit.name in Goap.orders.enemy_leaders_orders:
			order = Goap.orders.enemy_leaders_orders[unit.name]
	Goap.orders.set_leader(unit, order)
	var lane = agent.get_state("lane")
	var path = WorldState.get_state("lanes")[lane].duplicate()
	if unit.team == "red": path.reverse()
	Goap.move.point(unit, path[0])


func on_arrive(agent):
	agent.set_state("arrived_at_retreat", true)
