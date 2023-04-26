extends "../Goal.gd"


# leaders retreat behavior


func get_class_name(): return "RetreatGoal"


func get_desired_state(_agent) -> Dictionary:
	return { "ready_to_fight": true }


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var already_retreating = agent.get_state("is_retreating")
	if already_retreating: return true
	if should_retreat(unit):
		agent.set_state("is_retreating", true)
		agent.set_state("arrived_at_retreat", false)
		agent.set_state("ready_to_fight", false)
		return true
	# unit aint retreating nor should retreat
	return false


func priority(_agent) -> int:
	return 5
	# todo: dynamic priority


func should_retreat(unit):
	var hp = Behavior.modifiers.get_value(unit, "hp")
	match unit.tactics:
		"escape":
			return true
		"defensive":
			if unit.current_hp < hp / 2:
				return true
		"default":
			if unit.current_hp < hp / 3:
				return true
	return false

