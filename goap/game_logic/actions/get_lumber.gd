# =============================================================================
# GOAP-GUIDE: GetLumber - action (goap/game_logic/actions/get_lumber.gd)
# =============================================================================
# Purpose   : Send a lumberjack to closest_tree, play the cut channel, and
#             produce has_wood.
# Plannable : yes - NeedLumber({collected_wood: true}) -> GetLumber -> ReturnLumber.
# is_valid  : WorldState "is_game_active" is true (read with default false: a
#             typed -> bool must never return the null of an unset key).
# cost      : 1
# precond   : {}
# effects   : {"has_wood": true}
# enter     : Move.point(unit, closest_tree).
# perform   : false until the FINAL arrival (arrived_at_destination latched by
#             Collisions); then starts the cut channel once (cutting latch)
#             and completes when has_wood is set -- this is a coroutine (await),
#             so the fact is NOT set synchronously.
# exit      : cutting = false (a pending cut continuation no longer pays off).
# Traps     : the arrival facts are the interface (Collisions ->
#             ArriveAtDestination.advance_path). closest_tree is set at spawn.
# See       : docs/ai/world-state.md (has_wood, collected_wood).
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "GetLumber"


const cut_time = 6


func is_valid(_agent) -> bool:
	# Default to false: get_state returns null for an unset key, and a typed
	# -> bool returning null is a script error that aborts the planner's
	# action loop mid-search (see COVERAGE.md known bugs).
	return WorldState.get_state("is_game_active", false)


func get_cost(_agent):
	# plans will sum up their actions costs and the lower cost plan is chosen
	return 1


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return { "has_wood": true }


func perform(agent, _delta) -> bool:
	if agent.get_state("has_wood", false):
		return true
	if not agent.get_state("arrived_at_destination", false):
		return false
	if not agent.get_state("cutting", false):
		agent.set_state("cutting", true)
		_cut(agent)  # fire-and-forget coroutine (see _cut)
	return false


func enter(agent):
	var unit = agent.get_unit()
	var closest_tree = agent.get_state("closest_tree")
	Goap.get_action("Move").point(unit, closest_tree)


func exit(agent):
	# A goal switch mid-cut must cancel the pending continuation: the await
	# below only pays has_wood while `cutting` is still true.
	agent.set_state("cutting", false)


func _cut(agent) -> void:
	var unit = agent.get_unit()
	# fake cut animation
	unit.set_state("attack")
	if unit.channeling_timer.time_left > 0:
		unit.channeling_timer.stop()
	unit.channeling_timer.wait_time = cut_time
	unit.channeling_timer.start()
	# cut animation end
	await unit.channeling_timer.timeout
	if agent.get_state("cutting", false):
		agent.set_state("has_wood", true)
