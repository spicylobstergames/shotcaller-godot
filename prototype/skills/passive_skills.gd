extends Node


# self = Skills


const LEADER_PASSIVES: SkillResource = preload("res://skills/resources/leader_passives.tres")
var leader: Dictionary = LEADER_PASSIVES.attributes


func get_value(unit, skill_name):
	if unit.type == "leader":
		var leader_skills = leader[unit.display_name]
		if skill_name in leader_skills:
			return leader_skills[skill_name]
	return 0


func projectile_release(attacker):
	if attacker.display_name in leader:
		var attacker_skills = leader[attacker.display_name]
		
		if "multishot" in attacker_skills:
			var enemies = attacker.get_units_in_sight({ "team": attacker.opponent_team() })
			var sorted = attacker.sort_by_distance(enemies)
			for enemy in sorted:
				if (enemy.unit != attacker.target and 
					Goap.get_action("ChooseTarget").in_range(attacker, enemy.unit)):
					secondary_projectile(attacker, enemy.unit)


func secondary_projectile(attacker, target):
	var target_position = target.global_position + target.collision_position
	attacker.weapon.look_at(target_position)
	Goap.get_action("RangeAttack").projectile_start(attacker,target)



func hit_modifiers(attacker, target, projectile, modifiers):
	var damage
	if modifiers.has("damage"): 
		damage = modifiers.damage
	else:
		damage = Modifiers.get_value(attacker, "damage")
	modifiers = {
		"damage": damage,
		"cleave": "cleave" in modifiers,
		"dodge": false,
		"counter": true,
		"pierce": false
	}
	if target and target.display_name in leader:
		var target_skills = leader[target.display_name]
		
		if "dodge" in target_skills:
			modifiers.dodge = (randf() <  target_skills.dodge)
			
		if not modifiers.counter:
			if "counter" in target_skills and not attacker.ranged:
				modifiers.damage = target_skills.counter
				Goap.get_goal("EnemyDefeated").take_hit(target, attacker, projectile, modifiers)
			
	if attacker.display_name in leader:
		var attacker_skills = leader[attacker.display_name]
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
				Modifiers.remove(attacker, "attack_speed", "agile")
				Modifiers.add(attacker, "attack_speed", "agile", attacker_skills.agile * min(10, attacker.attack_count))
	
	return modifiers
