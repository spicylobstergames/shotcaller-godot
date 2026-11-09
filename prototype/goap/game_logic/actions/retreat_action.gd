extends "res://goap/goap_system/action_contract.gd"


func get_class_name():
	return "Retreat"


func is_valid(agent) -> bool:
	return agent.get_unit().moves


func get_effects() -> Dictionary:
	return {"arrived_at_retreat": true}


func perform(agent, _delta) -> bool:
	return agent.get_state("arrived_at_retreat", false)


func enter(agent):
	var unit = agent.get_unit()
	agent.set_state("is_retreating", true)
	var lane = agent.get_state("lane")
	var path = Goap.get_goal("WalkLane").get_lane_path(lane, unit.team, false)
	if path.is_empty():
		return
	var recover_point = path[0]
	var half = WorldState.get_state("map").half_tile_size
	recover_point.x += (randf() * 2 * half) - half
	recover_point.y += (randf() * 2 * half) - half
	unit.final_destiny = recover_point
	Goap.get_action("Navigate").follow_path(unit, path)
	

func on_arrive(agent):
	agent.set_state("arrived_at_retreat", true)
	
	
func exit(agent):
	agent.set_state("is_retreating", false)
