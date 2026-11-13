extends "res://goap/goap_system/action_contract.gd"


func get_class_name():
	return "AttackEnemy"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.attacks


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {"enemy_in_attack_range": true}


func get_effects() -> Dictionary:
	return {
		"enemy_dead": true,
		"friends_safe": true
		}


func perform(agent, _delta) -> bool:
	var unit = agent.get_unit()
	var target = unit.target
	var choose_target = Goap.get_action("ChooseTarget")
	if not is_instance_valid(target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		agent.set_state("enemy_dead", false)
		return true
	if target.dead:
		agent.set_state("enemy_dead", true)
		agent.set_state("target", null)
		return true
	if not choose_target.can_hit(unit, target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		agent.set_state("enemy_dead", false)
		return true
	var target_in_range = choose_target.in_range(unit, target)
	agent.set_state("enemy_in_attack_range", target_in_range)
	return not target_in_range


func enter(agent):
	var unit = agent.get_unit()
	var target = unit.target
	if not is_instance_valid(target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		agent.set_state("enemy_dead", false)
		return
	if target.dead:
		agent.set_state("enemy_dead", true)
		agent.set_state("target", null)
		return
	if not Goap.get_action("ChooseTarget").can_hit(unit, target):
		agent.set_state("target", null)
		agent.set_state("enemy_in_attack_range", false)
		agent.set_state("enemy_dead", false)
		return
	if Goap.get_action("ChooseTarget").is_valid_target(unit, target):
		point(unit, target.global_position + target.collision_position)
	else:
		unit.final_destiny = target.global_position
		Goap.get_action("Navigate").move(unit, target.global_position)


func on_animation_end(agent):
	var unit = agent.get_unit()
	var target = unit.target
	
	if target and target.dead:
		agent.set_state("enemy_dead", false)
	
	var choose_target = Goap.get_action("ChooseTarget")
	if is_instance_valid(target) and choose_target.can_hit(unit, target):
		if choose_target.in_range(unit, target):
			point(unit, target.global_position + target.collision_position)
		else:
			unit.final_destiny = target.global_position
			Goap.get_action("Navigate").move(unit, target.global_position)
	else:
		Goap.get_action("Move").stop(unit)


func exit(agent):
	var unit = agent.get_unit()
	Goap.get_action("Move").stop(unit)


func point(unit, target_point: Vector2) -> void:
	if (
		unit.attacks
		and not unit.agent.get_state("is_stunned")
		and Goap.get_action("Move").in_bounds(target_point)
	):
		if unit.ranged and unit.weapon:
			unit.weapon.look_at(target_point)

		if not unit.target:
			var neighbors = Collisions.get_units_in_radius(target_point, 1)
			if neighbors:
				var choose_target = Goap.get_action("ChooseTarget")
				var target = choose_target.select_target(unit, neighbors)
				if choose_target.is_valid_target(unit, target):
					unit.agent.set_state("target", target)

		unit.aim_point = target_point
		unit.mirror_look_at(target_point)
		var animations = unit.get_node_or_null("animations")
		if animations:
			animations.speed_scale = Modifiers.get_value(unit, "attack_speed")
		unit.set_state("attack")
