extends GoapAction

class_name ReturnLumber

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
		if agent.get_state("returning_wood"):
				return true
		return false

func enter(agent):
		Behavior.move.move(agent.get_unit(), Vector2(458,570))

func on_arrive(agent):
		agent.set_state("returning_wood", true)
		agent.set_state("has_wood",false)
		# heal all player buildings
		for building in agent.get_unit().game.all_buildings:
				if agent.get_unit().team == building.team:
						building.heal(building.regen)
		
		if agent.get_unit().team == "neutral":
				agent.get_unit().visible = false
