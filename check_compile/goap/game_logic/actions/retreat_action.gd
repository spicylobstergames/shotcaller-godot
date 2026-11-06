extends "res://goap/goap_system/action_contract.gd"


func get_class_name():
	return "RetreatAction"


func is_valid(agent) -> bool:
	return agent.get_unit().moves


func get_cost(_agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return {"arrived_at_retreat": true}


func perform(agent, _delta) -> bool:
	return agent.get_state("arrived_at_retreat", false)


func enter(agent):
	var unit = agent.get_unit()
	unit.agent.set_state("is_retreating", true)
	# clear previous path and targets
	unit.current_path = []
	agent.set_state("target", null)
	var lane = agent.get_state("lane")
	var path = WorldState.get_state("lanes")[lane].duplicate()
	if unit.team == "red":
		path.reverse()
	Goap.navigation.navigate_to(unit, path[0])


func on_arrive(agent):
	agent.set_state("arrived_at_retreat", true)
