# =============================================================================
# GOAP-GUIDE: Hide - action (goap/game_logic/actions/hide.gd)
# =============================================================================
# Purpose   : Run to deliver_position and hide until the threat passes (or the
#             hide timer expires).
# Plannable : yes - NeedSafety({is_threatened: false}) -> Hide.
# cost      : 1 (default)
# precond   : {}
# effects   : {"is_threatened": false}
# enter     : Move.point(unit, deliver_position); is_running = true.
# perform   : false until the FINAL arrival (arrived_at_destination latched by
#             Collisions); then hides once (is_hiding latch) and completes
#             once hiding_counter > max_wait_seconds (5, driven by
#             on_every_second).
# exit      : unit.show(); clears is_hiding / is_threatened / hiding_counter.
# Traps     : NeedSafety is only in the lumberjack's goals_list, and
#             deliver_position is set at spawn. The arrival facts are the
#             interface (Collisions -> ArriveAtDestination.advance_path).
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "Hide"


const max_wait_seconds = 5


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return { "is_threatened": false }


func enter(agent):
	var unit = agent.get_unit()
	var deliver_position = agent.get_state("deliver_position")
	Goap.get_action("Move").point(unit, deliver_position)
	agent.set_state("is_running", true)


func perform(agent, _delta) -> bool:
	if not agent.get_state("is_hiding", false):
		# The FINAL arrival latches the hiding facts exactly once. (The old
		# on_arrive hook fired on every waypoint of the route.)
		if not agent.get_state("arrived_at_destination", false):
			return false
		agent.get_unit().hide()
		agent.set_state("is_running", false)
		agent.set_state("is_hiding", true)
		agent.set_state("hiding_counter", 0)
		return false
	# hiding: counter driven by on_every_second
	var hiding_counter = agent.get_state("hiding_counter")
	return hiding_counter and hiding_counter > max_wait_seconds


func on_every_second(agent):
	var is_threatened = agent.get_state("is_running")
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
	for enemy in enemies:
		if enemy.attacks:
			is_threatened = true
			agent.set_state("hiding_counter", 0)
			break
	agent.set_state("hide_threatened", is_threatened)
	#counter
	if agent.get_state("is_hiding") and not agent.get_state("hide_threatened"):
		var c = agent.get_state("hiding_counter")
		agent.set_state("hiding_counter", c+1)


func exit(agent):
	agent.get_unit().show()
	agent.set_state("is_hiding", false)
	agent.set_state("is_threatened", false)
	agent.set_state("hiding_counter", 0)
