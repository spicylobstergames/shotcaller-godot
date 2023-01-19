extends "../Action.gd"

class_name WaitOut

func get_class(): return "WaitOut"


func is_valid(blackboard) -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(blackboard) -> int:
	return 5


func get_preconditions() -> Dictionary:
	return {
				"arrived_at_retreat": true
		}


func get_effects() -> Dictionary:
	return {
		"is_retreating": false,
	}

func enter(agent):
		Behavior.move.stop(agent.get_unit())

func perform(agent, delta) -> bool:
		var unit = agent.get_unit()	
		if !Behavior.orders.should_retreat(unit):
				return true
		return not agent.get_state("is_retreating")

func exit(agent):
		agent.set_state("is_retreating", false)
		agent.set_state("arrived_at_retreat", false)
		agent.set_state("command_retreat", false)
		agent.get_unit().retreating = false
		print("exit")
