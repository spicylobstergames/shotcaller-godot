extends "../Action.gd"

#class_name ReturnLumber

func get_class(): return "ReturnLumber"


func get_cost(blackboard) -> int:
		return 5


func get_preconditions() -> Dictionary:
	return {
		"has_wood": true,
	}


func get_effects() -> Dictionary:
	return {
		"collected_wood": true,
	}

func exit(agent):
	agent.set_state("returning_wood", false)
	pass


func perform(agent, delta) -> bool:
	return agent.get_state("returning_wood")


func enter(agent):
		Behavior.move.point(agent.get_unit(), agent.get_state("lumbermill_position"))


func on_arrive(agent):
	agent.set_state("returning_wood", true)
	agent.set_state("has_wood",false)
	# heal all player buildings
	for building in agent.get_unit().game.all_buildings:
		if agent.get_unit().team == building.team:
				building.heal(building.regen)
	
	if agent.get_unit().team == "neutral":
		agent.get_unit().visible = false
