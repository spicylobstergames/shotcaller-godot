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
		"is_retreating": false,
	}

func perform(agent, delta) -> bool:
	var unit = agent.get_unit()	
	if !Behavior.orders.should_retreat(unit) and unit.point_collision(unit.position,unit.game.map.half_tile_size):
		agent.set_state("is_retreating", false)
		agent.get_unit().retreating = false
		return true
	return not agent.get_state("is_retreating")

func enter(agent):
	Behavior.orders.retreat(agent.get_unit())
				
