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
# perform   : returns arrived_at_retreat.
# on_arrive : sets arrived_at_retreat = true.
# exit      : is_retreating = false.
# Traps     : arrival must come through Collisions -> unit_arrived; Recover no
#             longer delegates into ArriveAtDestination (wrong arg + double
#             path advance).
# =============================================================================

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
	var path = agent.get_goal("WalkLane").get_lane_path(lane, unit.team, false)
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
