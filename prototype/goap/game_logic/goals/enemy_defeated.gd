extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "EnemyDefeated"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	if not unit.attacks:
		Goap.get_action("AttackEnemy").set_target(unit, null)
		agent.set_state("enemy_dead", false)
		agent.set_state("enemy_in_attack_range", false)
		return false
	var target = unit.target
	var enemies_in_range = unit.get_units_in_attack_range({"team": unit.opponent_team()})
	var attack_action = Goap.get_action("AttackEnemy")
	var target_in_range = attack_action.select_target(unit, enemies_in_range)
	if target_in_range:
		target = target_in_range
	elif not unit.moves or not attack_action.can_hit(unit, target):
		target = null
		if unit.moves:
			var enemies_in_sight = unit.get_units_in_sight({"team": unit.opponent_team()})
			target = attack_action.select_target(unit, enemies_in_sight)
	attack_action.set_target(unit, target)
	var has_target = attack_action.can_hit(unit, target)
	agent.set_state("enemy_dead", false)
	agent.set_state("enemy_in_attack_range", has_target and attack_action.in_range(unit, target))
	return has_target


func priority(_agent) -> int:
	return 4


func get_desired_state(_agent) -> Dictionary:
	return {"enemy_dead": true}


func apply_damage_over_time(agent) -> void:
	var unit = agent.get_unit()
	if unit.dead:
		return
	var dot_effects = Modifiers.get_dot(unit)
	if dot_effects:
		for dot in dot_effects:
			take_hit(dot.attacker, unit, null, {"damage": dot.damage})


func take_hit(attacker, target, projectile = null, hit_modifiers = {}) -> void:
	var modifiers = Skills.hit_modifiers(attacker, target, projectile, hit_modifiers)

	if projectile:
		if not modifiers.pierce:
			Goap.get_action("RangeAttack").projectile_stuck(attacker, target, projectile)

		if projectile.targets != null and projectile.targets.find(target) < 0:
			projectile.targets.append(target)

	if target and not target.dead and not target.immune:
		var damage = 0
		if not modifiers.dodge:
			damage = max(1, modifiers.damage - Modifiers.get_value(target, "defense"))
			target.current_hp -= damage
			attacker.attack_count += 1
			if attacker.type == "leader":
				target.last_attacker = attacker
				target.assist_candidates[attacker] = Time.get_ticks_msec()

		if not modifiers.counter:
			target.was_attacked(attacker, damage)

		if target.hud:
			target.hud.update_hpbar()

		if target.type == "building" and target.subtype == "backwood":
			var hp = Modifiers.get_value(target, "hp")
			var rate = float(target.current_hp) / float(hp)
			var tax_action = Goap.get_action("TaxesAction")
			var tax = tax_action.get_tax_for_team(target.team)
			var limit = tax_action.tax_conquer_limit[tax]
			if rate <= limit:
				Goap.get_action("ConquerAction").lose_building(target)

		if target.current_hp <= 0:
			target.current_hp = 0
			target.die()
			if target.type == "leader":
				var player_team = WorldState.get_state("player_team")
				if target.team == player_team:
					WorldState.set_state("player_deaths", WorldState.get_state("player_deaths") + 1)
				else:
					WorldState.set_state("enemy_deaths", WorldState.get_state("enemy_deaths") + 1)
				if attacker.team == player_team:
					WorldState.set_state("player_kills", WorldState.get_state("player_kills") + 1)
				else:
					WorldState.set_state("enemy_kills", WorldState.get_state("enemy_kills") + 1)
