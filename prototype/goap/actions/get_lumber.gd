extends "../Action.gd"


func get_class(): return "GetLumber"


const cut_time = 6


func is_valid(agent) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(agent):
	# plans will sum up their actions costs and the lower cost plan is chosen
	return 3


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return { "has_wood": true }


func perform(agent, delta) -> bool:
	return agent.get_state("has_wood")


func enter(agent):
	var unit = agent.get_unit()
	unit.working = true
	var closest_tree = agent.get_state("closest_tree")
	Behavior.move.point(unit, closest_tree)


func on_arrive(agent):
	var unit = agent.get_unit()
	# fake cut animation
	unit.set_state("attack")
	if unit.channeling_timer.time_left > 0: 
		unit.channeling_timer.stop()
	unit.channeling_timer.wait_time = cut_time
	unit.channeling_timer.start()
	# cut animation end
	yield(unit.channeling_timer, "timeout")
	unit.working = true
	agent.set_state("has_wood",true)


func on_animation_end(agent):
	var unit = agent.get_unit()
	for enemy in unit.get_units_in_sight({ "team": unit.opponent_team() }):
		if enemy.attacks:
			agent.set_state("is_threatened", true)
			break

