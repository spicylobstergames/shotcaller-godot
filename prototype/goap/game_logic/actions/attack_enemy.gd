extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "AttackEnemy"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.attacks and can_hit(unit, unit.target)


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
	var target_in_range = in_range(agent.get_unit(), target)
	agent.set_state("enemy_in_attack_range", target_in_range)
	return not target_in_range


func enter(agent):
	var unit = agent.get_unit()
	var target = unit.target
	if not is_instance_valid(target) or target.dead:
		agent.set_state("enemy_dead", true)
		return
	if is_valid_target(unit, target):
		point(unit, target.global_position + target.collision_position)
	else:
		unit.final_destiny = target.global_position
		Goap.navigation.move(unit, target.global_position, false)


func on_animation_end(agent):
	var unit = agent.get_unit()
	var target = unit.target

	if is_instance_valid(target) and can_hit(unit, target):
		if in_range(unit, target):
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
				var target = closest_enemy_unit(unit, neighbors)
				if is_valid_target(unit, target):
					set_target(unit, target)

		unit.aim_point = target_point
		unit.mirror_look_at(target_point)
		var animations = unit.get_node_or_null("animations")
		if animations:
			animations.speed_scale = Modifiers.get_value(unit, "attack_speed")
		unit.set_state("attack")


func set_target(unit, target) -> void:
	if not target:
		unit.agent.set_state("hunting", false)
		unit.attack_count = 0
		Modifiers.remove(unit, "attack_speed", "agile")
		unit.agent.set_state("has_attack_target", false)
	else:
		unit.agent.set_state("has_attack_target", true)
	if target and unit.moves:
		unit.agent.set_state("hunting", true)
	if unit.target != target:
		unit.attack_count = 0
		Modifiers.remove(unit, "attack_speed", "agile")
		unit.last_target = unit.target
	unit.target = target


func closest_enemy_unit(unit, enemies):
	var filtered = []
	for enemy in enemies:
		if can_hit(unit, enemy):
			filtered.append(enemy)
	var sorted = unit.sort_by_distance(filtered)
	if sorted:
		return sorted[0].unit


func select_target(unit, enemies):
	var filtered = []
	for enemy in enemies:
		if can_hit(unit, enemy):
			filtered.append(enemy)
	if filtered.is_empty():
		return null
	if filtered.size() == 1:
		return filtered[0]
	var sorted = unit.sort_by_distance(filtered)
	var closest_unit = sorted[0].unit
	if filtered.size() == 2:
		var further_unit = sorted[1].unit
		var index1 = unit.priority.find(closest_unit.type)
		var index2 = unit.priority.find(further_unit.type)
		if index2 < index1:
			return further_unit
	if not unit.ranged:
		return closest_unit
	for priority_type in unit.priority:
		for enemy in sorted:
			if enemy.unit.type == priority_type:
				return enemy.unit
	return closest_unit


func can_hit(attacker, target) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	return (
		attacker != null
		and target != null
		and target != attacker
		and target.team != attacker.team
		and target.type != "block"
		and not target.dead
		and not target.immune
	)


func in_range(attacker, target) -> bool:
	var att_pos = attacker.global_position + attacker.attack_hit_position
	var att_rad = Modifiers.get_value(attacker, "attack_range")
	var tar_pos = target.global_position + target.collision_position
	var tar_rad = target.collision_radius
	return Utils.circle_collision(att_pos, att_rad, tar_pos, tar_rad)


func is_valid_target(attacker, target) -> bool:
	return can_hit(attacker, target) and in_range(attacker, target)


func on_attack_end(unit) -> void:
	if not unit.attacks or unit.target:
		return
	if not unit.current_path.is_empty():
		Goap.navigation.follow_path(unit, unit.current_path)
	elif unit.current_destiny != Vector2.ZERO:
		Goap.move.point(unit, unit.current_destiny)
	else:
		Goap.move.stop(unit)
