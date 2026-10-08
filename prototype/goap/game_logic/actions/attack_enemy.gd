extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "AttackEnemy"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.attacks and Goap.attack.can_hit(unit, unit.target)
	
	
func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {"enemy_in_attack_range": true}


func get_effects() -> Dictionary:
	return {"enemy_dead": true}


func perform(agent, _delta) -> bool:
	var target = agent.get_unit().target
	if not is_instance_valid(target) or target.dead:
		agent.set_state("enemy_dead", true)
		return true
	var in_range = Goap.attack.in_range(agent.get_unit(), target)
	agent.set_state("enemy_in_attack_range", in_range)
	return not in_range


func enter(agent):
	var unit = agent.get_unit()
	var target = unit.target
	if not is_instance_valid(target) or target.dead:
		agent.set_state("enemy_dead", true)
		return
	if Goap.attack.is_valid_target(unit, target):
		Goap.attack.point(unit, target.global_position + target.collision_position)
	else:
		unit.final_destiny = target.global_position
		Goap.navigation.move(unit, target.global_position, false)


func on_animation_end(agent):
	var unit = agent.get_unit()
	var target = unit.target
	
	if is_instance_valid(target) and Goap.attack.can_hit(unit, target):
		if Goap.attack.in_range(unit, target):
			Goap.attack.point(unit, target.global_position + target.collision_position)
		else:
			unit.final_destiny = target.global_position
			Goap.navigation.move(unit, target.global_position, false)
	else:
		Goap.move.stop(unit)



func exit(agent):
	var unit = agent.get_unit()
	Goap.move.stop(unit)
