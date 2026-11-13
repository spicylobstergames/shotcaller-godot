extends "res://goap/goap_system/goal_contract.gd"


# hide behavior


func get_class_name(): return "NeedSafety"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_sight({"team": unit.opponent_team()})
	agent.set_state("is_threatened", not enemies.is_empty())
	return not enemies.is_empty()


func priority(_agent) -> int:
	return 10


func get_desired_state(_agent) -> Dictionary:
	return { "is_threatened": false }
