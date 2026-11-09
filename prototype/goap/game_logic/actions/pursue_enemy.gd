extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "PursueEnemy"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.attacks


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {
		"is_stunned": false,
		"ready_to_fight": true, 
		"has_attack_target": true
	}


func get_effects() -> Dictionary:
	return {"enemy_in_attack_range": true}


func perform(agent, _delta) -> bool:
	var unit = agent.get_unit()
	var target = unit.target
	if not is_instance_valid(target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		return true
	if target.dead:
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		return true
	var in_range = agent.get_action("ChooseTarget").in_range(unit, target)
	agent.set_state("enemy_in_attack_range", in_range)
	agent.set_state("has_attack_target", true)
	if not unit.moves and not in_range:
		agent.set_state("target", null)
		return true
	if not in_range and (
		unit.current_destiny == Vector2.ZERO
		or unit.current_destiny.distance_to(target.global_position) > 8
	):
		unit.final_destiny = target.global_position
		agent.get_action("Navigate").move(unit, target.global_position)
	return in_range


func enter(agent):
	var unit = agent.get_unit()
	if not is_instance_valid(unit.target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		return
	if unit.target.dead:
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		return
	agent.set_state("enemy_in_attack_range", false)
	if not unit.moves:
		return
	unit.final_destiny = unit.target.global_position
	agent.get_action("Navigate").move(unit, unit.target.global_position)


func exit(agent):
	var unit = agent.get_unit()
	agent.get_action("Move").stop(unit)
