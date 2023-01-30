extends "../Action.gd"


func get_class(): return "RetreatAction"


func is_valid(agent) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(agent) -> int:
	return 5


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return { "arrived_at_retreat": true }


func perform(agent, delta) -> bool:
	return agent.get_state("arrived_at_retreat")


func enter(agent):
	print('enter retreat action')
	var unit = agent.get_unit()
	unit.agent.set_state("is_retreating", true)
	agent.set_state("retreat_pos", agent.get_unit().current_destiny)
	agent.set_state("current_path", [])
	Behavior.attack.set_target(unit, null)
	var order = Behavior.orders.player_leaders_orders[unit.name]
	if unit.team == WorldState.game.enemy_team:
		order = Behavior.orders.enemy_leaders_orders[unit.name]
	Behavior.orders.set_leader(unit, order)
	var lane = unit.lane
	var path = WorldState.game.map.lanes_paths[lane].duplicate()
	if unit.team == "red": 
		path.invert()
	Behavior.move.point(unit, path[0])


func on_arrive(agent):
	agent.set_state("arrived_at_retreat", true)
