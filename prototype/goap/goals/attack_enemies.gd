extends "../Goal.gd"


func get_class_name(): return "AttackEnemiesGoal"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_attack_range({"team": unit.opponent_team()})
	var target = Behavior.orders.select_target(unit, enemies)
	Behavior.attack.set_target(unit, target)
	
	return agent.get_state("has_attack_target")


func priority(_agent) -> int:
	return 4


func get_desired_state(_agent) -> Dictionary:
	return { "has_attack_target": false }
