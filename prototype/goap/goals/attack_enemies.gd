extends "../Goal.gd"


func get_class(): return "AttackEnemiesGoal"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_attack_range({"team": unit.opponent_team()})
	var target = Behavior.orders.select_target(unit, enemies)
	var is_valid_target = Behavior.attack.is_valid_target(unit, target)
	agent.set_state("target_enemy_active", is_valid_target)
	
	
	if is_valid_target:
		Behavior.attack.set_target(unit, target)
	
	return agent.get_state("target_enemy_active")


func priority(agent) -> int:
	return 10


func get_desired_state(agent) -> Dictionary:
	return { "target_enemy_active": false }
