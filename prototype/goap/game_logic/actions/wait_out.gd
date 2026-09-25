extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "WaitOut"


func is_valid(_agent) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return { "completed_path": true }


func get_effects() -> Dictionary:
	return { "ready_to_fight": true }


func enter(agent):
	Goap.move.stop(agent.get_unit())


func perform(agent, _delta) -> bool:
	var unit = agent.get_unit()
	var hp = Goap.modifiers.get_value(unit, "hp")
	var ready_to_fight = unit.current_hp > hp * 0.8
	return ready_to_fight


func exit(agent):
	var unit = agent.get_unit()
	agent.set_state("is_retreating", false)
	agent.set_state("ready_to_fight", true)
	if WorldState.get_state("selected_unit") == unit:
		Goap.path.resume_lane(agent.get_unit())
