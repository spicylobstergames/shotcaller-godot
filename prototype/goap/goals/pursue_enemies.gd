extends "../Goal.gd"


func get_class(): return "PursueEnemiesGoal"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var target = agent.get_state("attacker")
	var enemies = []
	
	if not target:
		enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
		target = Behavior.orders.select_target(unit, enemies)
	
	Behavior.attack.set_target(unit, target)
	
	#print(unit, unit.target)
	
	return agent.get_state("has_attack_target")


func priority(agent) -> int:
	return 3 # lower if unit curent_hp is low


func get_desired_state(agent) -> Dictionary:
	return { "has_attack_target": false }
