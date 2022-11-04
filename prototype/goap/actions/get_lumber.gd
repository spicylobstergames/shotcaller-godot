extends GoapAction

class_name GetLumber

func get_class(): return "GetLumber"


const cut_time = 6

func is_valid() -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(blackboard):
	if blackboard.has("position"):
		#var closest_tree = WorldState.get_closest_element("trees", blackboard)
		return int(Vector2(515,562).distance_to(blackboard.position) / 7)
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
	#var cut_position = WorldState.get_closest_element("trees", agent.blackboard)
	agent.get_unit().working = true
	agent.get_unit().after_arive = "cut"
	Behavior.move.move(agent.get_unit(), Vector2(515,562))

	


func on_arrive(agent):
	agent.get_unit().after_arive = "stop"
	agent.get_unit().set_state("attack")
	if agent.get_unit().channeling_timer.time_left > 0: 
		agent.get_unit().channeling_timer.stop()
	agent.get_unit().channeling_timer.wait_time = cut_time
	agent.get_unit().channeling_timer.start()
	
	# cut animation end
	yield(agent.get_unit().channeling_timer, "timeout")
	agent.get_unit().working = true
	agent.set_state("has_wood",true)


