extends "../Action.gd"

class_name AdvanceOnEnemy

func get_class(): return "AdvanceOnEnemy"


func is_valid(blackboard) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(blackboard) -> int:
	return 5


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {
		"is_game_active": false,
	}

func perform(agent, delta) -> bool:
	return false


func enter(agent):
	var path = agent.get_unit().game.maps.new_path(agent.get_unit().lane, agent.get_unit().team)
	if path != null:
		var new_path = agent.get_unit().cut_path(path.follow)
		var next_point = new_path.pop_front()
		agent.get_unit().current_path = new_path
		point(agent.get_unit(), next_point)


func point(unit, objective, smart_move = false): # move_and_attack
	Behavior.attack.set_target(unit, null)

	if objective: unit.objective = objective
	if (unit.attacks and Behavior.move.in_bounds(unit.objective) and
			not unit.retreating and not unit.stunned and not unit.channeling):
		if smart_move:
			var path = Behavior.follow.find_path(unit.global_position, unit.objective)
			unit.current_path = path
		var at_objective = (unit.global_position.distance_to(unit.objective) < unit.game.map.half_tile_size)
		var has_path = (unit.current_path.size() > 0)
		if not at_objective: 
			Behavior.move.move(unit, unit.objective) 
		elif has_path: 
			Behavior.follow.path(unit, unit.current_path, "move")
	

func move(unit, objective, smart_move):
	if unit.moves and objective:
		point(unit, objective, smart_move)
	else: stop(unit)



func resume(unit):
	point(unit, null)


func end(unit):
	if unit.current_destiny != unit.objective:
		point(unit, null)
	else: 
		stop(unit)


func react(target, attacker):
	point(target, attacker.global_position)


func ally_attacked(target, attacker):
	var allies = target.get_units_on_sight({"team": target.team})
	for ally in allies: react(ally, attacker)


func stop(unit):
	Behavior.move.stop(unit)


func on_idle_end(unit):
	point(unit, unit.global_position, true)


func smart(unit, objective):
	point(unit, objective, true)

