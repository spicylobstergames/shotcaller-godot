extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "Recover"


func get_desired_state(_agent) -> Dictionary:
	return {"ready_to_fight": true}


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var is_low_hp = should_retreat(unit)
	return is_low_hp


func enter(agent):
	agent.set_state("ready_to_fight", false)
	agent.set_state("is_retreating", true)
	agent.set_state("arrived_at_retreat", false)


func priority(_agent) -> int:
	return 10


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


func on_arrive(agent):
	agent.get_goal("ArriveAtDestination").on_arrive(agent)
