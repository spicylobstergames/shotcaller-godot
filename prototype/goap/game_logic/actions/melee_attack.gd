extends "res://goap/goap_system/action_contract.gd"


func get_class_name() -> String:
	return "MeleeAttack"


func hit(unit) -> bool:
	var choose_target = Goap.get_action("ChooseTarget")
	var attack_position = unit.global_position + unit.attack_hit_position
	var did_hit := false

	if choose_target.can_hit(unit, unit.target) and choose_target.in_range(unit, unit.target):
		Goap.get_goal("EnemyDefeated").take_hit(unit, unit.target)
		did_hit = true

	if unit.display_name in Skills.leader:
		var attacker_skills = Skills.leader[unit.display_name]
		if "cleave" in attacker_skills:
			var neighbors = Collisions.get_units_in_radius(attack_position, unit.attack_hit_radius)
			for target in neighbors:
				if choose_target.can_hit(unit, target) and choose_target.in_range(unit, target):
					Goap.get_goal("EnemyDefeated").take_hit(unit, target, null, {"cleave": true})
	return did_hit
