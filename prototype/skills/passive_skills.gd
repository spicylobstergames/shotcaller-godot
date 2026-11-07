extends Node


# self = Skills


var leader: Dictionary = {}


func _ready() -> void:
	var passives = load("res://skills/resources/leader_passives.tres")
	if passives:
		var attrs = passives.get("attributes")
		if attrs is Dictionary:
			leader = attrs


func get_value(unit, skill_name):
	if unit.type == "leader":
		var leader_skills = leader.get(unit.display_name, {})
		if skill_name in leader_skills:
			return leader_skills[skill_name]
	return 0


func projectile_release(attacker):
	if not attacker: return
	if attacker.display_name in leader:
		var attacker_skills = leader[attacker.display_name]
		if not attacker_skills: return
		
		if "multishot" in attacker_skills:
			var enemies = attacker.get_units_in_sight({ "team": attacker.opponent_team() })
			var sorted = attacker.sort_by_distance(enemies)
			for enemy in sorted:
				if (enemy.unit != attacker.target and 
					_get_goap().get_action("ChooseTarget").in_range(attacker, enemy.unit)):
					secondary_projectile(attacker, enemy.unit)


func secondary_projectile(attacker, target):
	var target_position = target.global_position + target.collision_position
	attacker.weapon.look_at(target_position)
	_get_goap().get_action("RangeAttack").projectile_start(attacker,target)


func _get_goap() -> Node:
	return get_node("/root/Goap") if has_node("/root/Goap") else null


func _get_modifiers() -> Node:
	return get_node("/root/Modifiers") if has_node("/root/Modifiers") else null



func hit_modifiers(attacker, target, projectile, modifiers):
	var damage
	if modifiers.has("damage"): 
		damage = modifiers.damage
	else:
		damage = _get_modifiers().get_value(attacker, "damage")
	modifiers = {
		"damage": damage,
		"cleave": "cleave" in modifiers,
		"dodge": false,
		"counter": modifiers.get("counter", true),
		"pierce": false
	}
	if target and target.display_name in leader:
		var target_skills = leader.get(target.display_name, {})
		if not target_skills: return
		
		if "dodge" in target_skills:
			modifiers.dodge = (randf() <  target_skills.dodge)
			
		if not modifiers.counter:
			if "counter" in target_skills and not attacker.ranged:
				modifiers.damage = target_skills.counter
				_get_goap().get_goal("EnemyDefeated").take_hit(target, attacker, projectile, modifiers)
			
	if attacker.display_name in leader:
		var attacker_skills = leader.get(attacker.display_name, {})
		if not attacker_skills: return
		if not modifiers.counter:
			if "stun" in attacker_skills and target.type != "building":
				if randf() < attacker_skills.stun: 
					target.stun_start()
			
			if "critical" in attacker_skills:
				if randf() <  attacker_skills.critical:
					modifiers.damage *= 2
			
			if "cleave" in attacker_skills:
				if modifiers.cleave:
					modifiers.damage *= attacker_skills.cleave
			
			if "pierce" in attacker_skills:
				if randf() <  attacker_skills.pierce:
					modifiers.pierce = true
			
			if "bleed" in attacker_skills:
				modifiers.damage += attacker_skills.bleed * min(10, attacker.attack_count)
			
			if "agile" in attacker_skills:
				_get_modifiers().remove(attacker, "attack_speed", "agile")
				_get_modifiers().add(attacker, "attack_speed", "agile", attacker_skills.agile * min(10, attacker.attack_count))
	
	return modifiers
