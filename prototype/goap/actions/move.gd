extends "../Action.gd"


func get_class(): return "Move"


func is_valid(agent) -> bool:
	return true


func get_cost(agent) -> int:
	return 10


func get_preconditions() -> Dictionary:
	return { "command_attack_point": true }


func get_effects() -> Dictionary:
	return { "arrived_at_target": true }


func perform(agent, delta) -> bool:
	return agent.get_state("arrived_at_target")


func enter(agent):
	point(agent.get_unit(), agent.get_state("command_attack_point"))


func point(unit, objective, smart_move = false): # move_and_attack
	Behavior.advance.point(unit, objective, smart_move)
	

func move(unit, objective, smart_move):
	if unit.moves and objective:
		point(unit, objective, smart_move)
	else: stop(unit)



func resume(unit):
	point(unit, null)


func end(unit):
		unit.agent.set_state("arrived_at_target", true)
		stop(unit)


func react(target, attacker):
	point(target, attacker.global_position)


func ally_attacked(target, attacker):
	var allies = target.get_units_on_sight({"team": target.team})
	for ally in allies: react(ally, attacker)


func stop(unit):
	Behavior.move.stop(unit)


func smart(unit, objective):
	point(unit, objective, true)

