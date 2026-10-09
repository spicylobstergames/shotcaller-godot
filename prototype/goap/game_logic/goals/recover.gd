extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "Recover"


func get_desired_state(_agent) -> Dictionary:
	return {"ready_to_fight": true}


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	if agent.get_state("is_retreating", false):
		return true
	if should_retreat(unit):
		agent.set_state("is_retreating", true)
		agent.set_state("arrived_at_retreat", false)
		agent.set_state("ready_to_fight", false)
		return true
	return false


func priority(_agent) -> int:
	return 5


func should_retreat(unit) -> bool:
	var hp = Modifiers.get_value(unit, "hp")
	match unit.agent.get_state("tactic", "default"):
		"retreat":
			return true
		"defend":
			return unit.current_hp < hp / 2
		"default":
			return unit.current_hp < hp / 3
	return false
