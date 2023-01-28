extends "../Action.gd"


func get_class(): return "AdvanceOnEnemy"


func is_valid(agent) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(agent) -> int:
	# cost of pursue should be higher than attacking
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
	var unit = agent.get_unit()
	if agent.get_state("command_attack_target"):
		Behavior.attack.set_target(unit, agent.get_state("command_attack_target"))
		Behavior.advance.point(unit, unit.target.position)
		return

	var enemies = unit.get_units_on_sight({"team": unit.opponent_team()})
	if enemies.size() > 0:
		var target = Behavior.orders.select_target(unit, enemies)
		if Behavior.attack.is_valid_target(unit, target):
			Behavior.attack.set_target(unit, target)
			Behavior.advance.point(unit, target.global_position)
	else :
		print('Attack enemy action but no target')


func end(unit):
	Behavior.move.stop(unit)
