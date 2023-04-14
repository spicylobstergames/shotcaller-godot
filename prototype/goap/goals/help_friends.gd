extends "../Goal.gd"


func get_class_name(): return "HelpFriendsGoal"


func is_valid(agent) -> bool:
	var attacker = ally_attacked(agent.get_unit())
	agent.set_state("react_target", attacker)
	return attacker != null


func priority(_agent) -> int:
	# higher if friend is low and self current hp is high
	return 2


func get_desired_state(_agent) -> Dictionary:
	return { "react_target": false }



func ally_attacked(unit):
	var allies = unit.get_units_in_sight({ "team": unit.team })
	for ally in allies:
		if ally.agent.get_state("being_attacked"):
			return ally.agent.get_state("attacker")
