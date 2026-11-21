# =============================================================================
# GOAP-GUIDE: Retreat - action (goap/game_logic/actions/retreat_action.gd)
# =============================================================================
# Purpose   : Walk back to the start of the unit's lane (its recovery point).
# Plannable : yes - Recover({ready_to_fight: true}) -> Retreat ->
#             WaitForRegeneration.
# is_valid  : unit.moves
# precond   : {} (default)
# effects   : {"arrived_at_retreat": true}
# enter     : is_retreating = true; follows the lane path from waypoint 0 with
#             a small random jitter.
# perform   : false until the FINAL arrival (arrived_at_destination latched by
#             Collisions); then latches arrived_at_retreat exactly once and
#             completes. Intermediate waypoints only advance the route.
# exit      : is_retreating = false.
# Traps     : the arrival facts are the interface (Collisions ->
#             ArriveAtDestination.advance_path); arrival used to ride the
#             unit_arrived signal dispatch.
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"


func get_class_name():
	return "Retreat"


func is_valid(agent) -> bool:
	return agent.get_unit().moves


func get_effects() -> Dictionary:
	return {"arrived_at_retreat": true}


func perform(agent, _delta) -> bool:
	if agent.get_state("arrived_at_retreat", false):
		return true
	if agent.get_state("arrived_at_destination", false):
		agent.set_state("arrived_at_retreat", true)
		return true
	return false


func enter(agent):
	var unit = agent.get_unit()
	agent.set_state("is_retreating", true)
	var lane = agent.get_state("lane")
	var path = agent.get_goal("WalkLane").get_lane_path(lane, unit.team, false)
	if path.is_empty():
		return
	var recover_point = path[0]
	var half = WorldState.get_state("map").half_tile_size
	recover_point.x += (randf() * 2 * half) - half
	recover_point.y += (randf() * 2 * half) - half
	unit.final_destiny = recover_point
	Goap.get_action("Navigate").follow_path(unit, path)


func exit(agent):
	agent.set_state("is_retreating", false)
