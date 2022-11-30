extends GoapGoal

class_name RetreatGoal

func get_class(): return "RetreatGoal"

#initially checks for enemies being around and being an attacking unit. If it becomes true, its sets the agent state and refers to it going forward
func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var hp = Behavior.modifiers.get_value(unit, "hp")
	if(agent.get_state("is_retreating")):
		return true
	match unit.tactics:
		"escape":
			agent.set_state("is_retreating", true)
			return true
		"defensive":
			if unit.current_hp < hp / 2:
				agent.set_state("is_retreating", true)
				return true
		"default":
			if unit.current_hp < hp / 3:
				agent.set_state("is_retreating", true)
				return true
	return false


func priority(agent) -> int:
	return 100


func get_desired_state(agent) -> Dictionary:
	return {
		"is_retreating": false
	}
