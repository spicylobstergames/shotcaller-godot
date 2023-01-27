extends "../Goal.gd"


func get_class(): return "PursueEnemiesGoal"


func get_desired_state(agent) -> Dictionary:
	return { "target_enemy_active": false }


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var enemies = unit.get_units_on_sight({
		"team": unit.opponent_team(),
		"dead": false
	})
	var has_targets = enemies.size() > 0
	agent.set_state("target_enemy_active", has_targets)
	return has_targets


func priority(agent) -> int:
	# priority of pursuing should be lower than attacking
	return 5
