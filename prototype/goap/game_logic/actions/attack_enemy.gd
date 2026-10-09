extends "res://goap/goap_system/action_contract.gd"


func get_class_name():
	return "AttackEnemy"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.attacks and agent.can_hit(unit.target)


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
	var target_in_range = agent.target_in_range(target)
	agent.set_state("enemy_in_attack_range", target_in_range)
	return not target_in_range


func enter(agent):
	var unit = agent.get_unit()
	var target = unit.target
	if not is_instance_valid(target) or target.dead:
		agent.set_state("enemy_dead", true)
		return
	if agent.is_valid_target(target):
		point(unit, target.global_position + target.collision_position)
	else:
		unit.final_destiny = target.global_position
		Goap.navigation.move(unit, target.global_position, false)


func on_animation_end(agent):
	var unit = agent.get_unit()
	var target = unit.target

	if is_instance_valid(target) and agent.can_hit(target):
		if agent.target_in_range(target):
			point(unit, target.global_position + target.collision_position)
		else:
			unit.final_destiny = target.global_position
			Goap.navigation.move(unit, target.global_position, false)
	else:
		Goap.move.stop(unit)


func exit(agent):
	var unit = agent.get_unit()
	Goap.move.stop(unit)


func point(unit, target_point: Vector2) -> void:
	if (
		unit.attacks
		and not unit.agent.get_state("is_stunned")
		and Goap.move.in_bounds(target_point)
	):
		if unit.ranged and unit.weapon:
			unit.weapon.look_at(target_point)

		if not unit.target:
			var neighbors = Collisions.get_units_in_radius(target_point, 1)
			if neighbors:
				var target = unit.agent.closest_enemy_unit(neighbors)
				if unit.agent.is_valid_target(target):
					unit.agent.set_state("target", target)

		unit.aim_point = target_point
		unit.mirror_look_at(target_point)
		var animations = unit.get_node_or_null("animations")
		if animations:
			animations.speed_scale = Modifiers.get_value(unit, "attack_speed")
		unit.set_state("attack")
