extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "EnemyDefeated"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var ready_to_fight = agent.get_state("ready_to_fight", true)
	if !ready_to_fight or !unit.attacks:
		return false
	var enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
	agent.set_state("opponents_in_sight", enemies)
	var opponents_in_sight = enemies.size() > 0
	return opponents_in_sight


func priority(_agent) -> int:
	return 6


func get_desired_state(_agent) -> Dictionary:
	return {"enemy_dead": true}
