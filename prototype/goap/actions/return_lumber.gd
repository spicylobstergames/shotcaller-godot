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

func perform(agent, delta) -> bool:
    if agent.get_state("collected_wood"):
        agent.set_state("collected_wood", false)
        return true
    return false

func enter(agent):
    Behavior.move.move(agent.unit, agent.unit.target.position)

func lumber_arive(agent):
    agent.set_state("collected_wood", true)
    agent.set_state("has_wood",false)
    # heal all player buildings
    for building in agent.unit.game.all_buildings:
        if agent.unit.team == building.team:
            building.heal(building.regen)
    
    if agent.unit.team == "neutral":
        agent.unit.visible = false