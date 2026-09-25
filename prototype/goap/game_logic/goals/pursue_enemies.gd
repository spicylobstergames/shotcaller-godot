extends "res://goap/goap_system/goal_contract.gd"


func get_class_name(): return "PursueEnemies"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var target = agent.get_state("attacker")
	var enemies = []
	
	if not target:
		enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
		target = Goap.orders.select_target(unit, enemies)
	
	Goap.attack.set_target(unit, target)
	
	return agent.get_state("has_attack_target")


func priority(_agent) -> int:
	return 3 # lower if unit curent_hp is low


func get_desired_state(_agent) -> Dictionary:
	return { "has_attack_target": false }
