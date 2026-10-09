extends "res://goap/goap_system/action_contract.gd"


func get_class_name() -> String:
	return "WaitForRegeneration"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return not unit.moves and unit.regen > 0


func get_effects() -> Dictionary:
	return {"ready_to_fight": true}


func enter(agent):
	Goap.move.stop(agent.get_unit())


func perform(agent, _delta) -> bool:
	var unit = agent.get_unit()
	var hp = Modifiers.get_value(unit, "hp")
	return unit.current_hp > hp * 0.8


func exit(agent):
	agent.set_state("is_retreating", false)
	agent.set_state("ready_to_fight", true)
