extends GoapAction
var game:Node

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
	var unit = agent.get_unit()
	var path = unit.game.maps.new_path(unit.lane, unit.team)
	if path: Behavior.follow.path(unit, path.follow, "advance")
