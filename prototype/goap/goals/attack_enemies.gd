extends "../Goal.gd"


func get_class(): return "AttackEnemiesGoal"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return agent.get_state("target_enemy_active") and Behavior.attack.is_valid_target(unit, unit.target)


func priority(agent) -> int:
	return 10


func get_desired_state(agent) -> Dictionary:
	return { "target_enemy_active": false }
