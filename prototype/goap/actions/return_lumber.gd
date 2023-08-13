extends "../Action.gd"


func get_class_name(): return "ReturnLumber"


func get_cost(_agent) -> int:
	return 5


func get_preconditions() -> Dictionary:
	return { "has_wood": true }


func get_effects() -> Dictionary:
	return { "collected_wood": true }


func perform(agent, _delta) -> bool:
	return !!agent.get_state("returning_wood")


func enter(agent):
	Behavior.move.point(agent.get_unit(), agent.get_state("deliver_position"))


func on_arrive(agent):
	var unit = agent.get_unit()
	agent.set_state("returning_wood", true)
	agent.set_state("has_wood", false)
	# heal all player buildings
	for building in WorldState.get_state("all_buildings"):
		if unit.team == building.team:
				building.heal(building.regen)


func exit(agent):
	agent.set_state("returning_wood", false)

