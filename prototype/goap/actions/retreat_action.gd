extends "../Action.gd"


func get_class(): return "RetreatAction"


func get_cost(agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return { "arrived_at_retreat": true }


func perform(agent, delta) -> bool:
	return agent.get_state("arrived_at_retreat")


func enter(agent):
	var unit = agent.get_unit()
	unit.agent.set_state("is_retreating", true)
	# clear previous path and targets
	agent.set_state("current_path", [])
	Behavior.attack.set_target(unit, null)
	# update lane data in case of lane change
	var order = Behavior.orders.player_leaders_orders[unit.name]
	if unit.team == WorldState.game.enemy_team:
		order = Behavior.orders.enemy_leaders_orders[unit.name]
	Behavior.orders.set_leader(unit, order)
	var lane = agent.get_state("lane")
	var path = WorldState.lanes[lane].duplicate()
	if unit.team == "red": path.invert()
	Behavior.move.point(unit, path[0])


func on_arrive(agent):
	agent.set_state("arrived_at_retreat", true)
