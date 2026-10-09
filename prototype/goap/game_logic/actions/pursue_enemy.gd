extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "PursueEnemy"


func is_valid(agent) -> bool:
	return agent.get_unit().moves and is_instance_valid(agent.get_unit().target)


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {"has_attack_target": true}


func get_effects() -> Dictionary:
	return {"enemy_in_attack_range": true}


func perform(agent, _delta) -> bool:
	var unit = agent.get_unit()
	var target = unit.target
	if not is_instance_valid(target) or target.dead:
		return true
	var in_range = agent.target_in_range(target)
	agent.set_state("enemy_in_attack_range", in_range)
	if not in_range and (
		unit.current_destiny == Vector2.ZERO
		or unit.current_destiny.distance_to(target.global_position) > 8
	):
		unit.final_destiny = target.global_position
		Goap.navigation.move(unit, target.global_position, false)
	return in_range


func enter(agent):
	var unit = agent.get_unit()
	if not is_instance_valid(unit.target) or unit.target.dead:
		agent.set_state("enemy_in_attack_range", false)
		return
	agent.set_state("enemy_in_attack_range", false)
	unit.final_destiny = unit.target.global_position
	Goap.navigation.move(unit, unit.target.global_position, false)


func exit(agent):
	var unit = agent.get_unit()
	Goap.move.stop(unit)
