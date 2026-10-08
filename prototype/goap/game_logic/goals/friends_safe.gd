extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "FriendsSafe"


func is_valid(agent) -> bool:
	var attacker = ally_attacked(agent.get_unit())
	agent.set_state("react_target", attacker)
	agent.set_state("friends_safe", false)
	return attacker != null


func priority(_agent) -> int:
	return 2


func get_desired_state(_agent) -> Dictionary:
	return {"friends_safe": true}


func ally_attacked(unit):
	for ally in unit.get_units_in_sight({"team": unit.team}):
		if ally.agent.get_state("being_attacked"):
			return ally.agent.get_state("attacker")
	return null
