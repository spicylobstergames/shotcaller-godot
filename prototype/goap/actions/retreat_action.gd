extends GoapAction

class_name RetreatAction

func get_class(): return "RetreatAction"


func is_valid(blackboard) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(blackboard) -> int:
	return 5


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {
		"arrived_at_retreat": true
	}

func perform(agent, delta) -> bool:
	var unit = agent.get_unit()	
	if Behavior.orders.should_retreat(unit) or agent.get_state("command_retreat") != null and agent.get_state("command_retreat") == true:
		return agent.get_state("arrived_at_retreat")
	else:
		agent.set_state("is_retreating", false)
		agent.set_state("command_retreat", false)
		agent.get_unit().retreating = false
		return true

func enter(agent):
	Behavior.orders.retreat(agent.get_unit())
	agent.set_state("retreat_pos", agent.get_unit().current_destiny)

func on_arrive(agent):
	agent.set_state("arrived_at_retreat", true)
				
