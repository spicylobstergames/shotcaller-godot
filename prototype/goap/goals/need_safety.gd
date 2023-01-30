extends "../Goal.gd"


func get_class(): return "NeedSafetyGoal"


func priority(agent) -> int:
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
	if not enemies.empty(): agent.set_state("is_threatened", true)
	return enemies.size() * 2


func get_desired_state(agent) -> Dictionary:
	return { "is_threatened": false }

