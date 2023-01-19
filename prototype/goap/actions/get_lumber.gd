extends "../Action.gd"

class_name GetLumber

func get_class(): return "GetLumber"


const cut_time = 6

func is_valid(blackboard) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(blackboard):
	#if blackboard.has("position"):
		#var closest_tree = agent.get_state("closest_tree")
		#return int(tree_pos.distance_to(blackboard.position) / 7)
	return 3


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {
		"has_wood": true,
	}

func perform(agent, delta) -> bool:
	return agent.get_state("has_wood")


func enter(agent):
	var unit = agent.get_unit()
	unit.working = true
	unit.after_arive = "cut"
	Behavior.move.point(unit, agent.get_state("closest_tree"))



func on_arrive(agent):
	var unit = agent.get_unit()
	unit.after_arive = "stop"
	unit.set_state("attack")
	if unit.channeling_timer.time_left > 0: 
		unit.channeling_timer.stop()
	unit.channeling_timer.wait_time = cut_time
	unit.channeling_timer.start()
	
	# cut animation end
	yield(unit.channeling_timer, "timeout")
	unit.working = true
	agent.set_state("has_wood",true)


