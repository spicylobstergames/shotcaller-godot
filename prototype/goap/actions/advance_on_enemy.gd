extends GoapAction

class_name AdvanceOnEnemy

func get_class(): return "AdvanceOnEnemy"


func is_valid() -> bool:
	return WorldState.get_state("is_game_active")


func get_cost(blackboard) -> int:
	return 5


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {
		"is_game_active": false,
	}

func perform(agent, delta) -> bool:
	return false

func enter(agent):
	var path = agent.get_unit().game.maps.new_path(agent.get_unit().lane, agent.get_unit().team)
	Behavior.follow.path(agent.get_unit(), path.follow, "advance")
