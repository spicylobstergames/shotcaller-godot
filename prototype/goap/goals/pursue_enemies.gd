extends "../Goal.gd"


func get_class(): return "PursueEnemiesGoal"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var enemies = unit.get_units_on_sight({ "team": unit.opponent_team() })
	var target = Behavior.orders.select_target(unit, enemies)
	var should_pursue = Behavior.attack.can_hit(unit, target) and not Behavior.attack.in_range(unit, target)
	agent.set_state("enemy_on_sight", should_pursue)
	
	if should_pursue:
		Behavior.attack.set_target(unit, target)
	
	return agent.get_state("enemy_on_sight")


func priority(agent) -> int:
	return 10


func get_desired_state(agent) -> Dictionary:
	return { "enemy_on_sight": false }
