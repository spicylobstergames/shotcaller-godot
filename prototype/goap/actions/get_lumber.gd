extends GoapAction

class_name GetLumber

func get_class(): return "GetLumber"


const cut_time = 6

func is_valid() -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(blackboard):
    if blackboard.has("position"):
        var closest_tree = WorldState.get_closest_element("trees", blackboard)
        return int(closest_tree.position.distance_to(blackboard.position) / 7)
    return 3


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {
		"has_wood": true,
	}

func perform(agent, delta) -> bool:
    if agent.get_state("has_wood"):
        return true
    return false

func enter(agent):
    var cut_position = WorldState.get_closest_element("trees", agent.blackboard)
    agent.unit.working = true
    agent.unit.after_arive = "cut"
    Behavior.move.move(agent.unit, cut_position)

    


func on_arrive(agent):
    agent.unit.after_arive = "stop"
    agent.unit.set_state("attack")
    if agent.unit.channeling_timer.time_left > 0: 
        agent.unit.channeling_timer.stop()
    agent.unit.channeling_timer.wait_time = cut_time
    agent.unit.channeling_timer.start()
    
    # cut animation end
    yield(agent.unit.channeling_timer, "timeout")
    agent.unit.working = true
    agent.set_state("has_wood",true)


