extends GoapAction

class_name AttackEnemy

func get_class(): return "AttackEnemy"


func is_valid(blackboard) -> bool:
	return blackboard["enemy_active"]


func get_cost(blackboard) -> int:
	return 3


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {
		"enemy_active": false,
	}

func perform(agent, delta) -> bool:
	return false

func enter(agent):
	agent.set_state("target_enemy", agent.unit.closest_unit(agent.unit.get_units_on_sight({"team": agent.unit.oponent_team()})))

func move(unit, objective, smart_move):
	if unit.moves and objective:
		if smart_move: Behavior.move.smart(unit, objective, "advance")
		else : Behavior.move.move(unit, objective)
	else: stop(unit)


func on_collision(unit):
	if unit.behavior == "advance" and unit.collide_target == unit.target:
		var target_position = unit.target.global_position + unit.target.collision_position
		Behavior.attack.point(unit, target_position)



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
	if unit.behavior == "advance":
		unit.set_behavior("stop")
		Behavior.move.stop(unit)


func on_idle_end(unit):
	if unit.behavior == "advance" or unit.behavior == "stop":
		if unit.attacks: point(unit, unit.global_position)


func smart(unit, objective):
	point(unit, objective, true)
					