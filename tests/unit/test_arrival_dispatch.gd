extends RefCounted

# Arrival is a GOAP state transition, NOT a unit signal (PR #239 feedback).
#
# Collisions detects arrival in its single movement loop and calls
# ArriveAtDestination.advance_path(unit): on a waypoint it advances the path;
# on the FINAL arrival it latches the facts (has_path=false, has_destiny=false,
# arrived_at_destination=true, unit stopped). Actions drive their arrival
# effects from perform() by reading those facts -- there is no unit_arrived
# wiring, no Agent.on_arrive dispatch, and no per-action on_arrive hooks.
#
# This file pins that contract:
#   - source lint: no signal dispatch in collisions/agent, no on_arrive hooks
#     left in the game_logic actions/goals;
#   - an arrival must NOT permanently disable WalkLane (the historical
#     lane_route_finished write-once bug);
#   - the migrated actions (ReturnLumber, Retreat, Hide, GetLumber, Order)
#     gate their effects on the FINAL arrival, never on an intermediate
#     waypoint and never before it;
#   - ReturnLumber.enter still routes to deliver_position.

const Agent = preload("res://goap/goap_system/agent.gd")
const ArriveAtDestination = preload("res://goap/game_logic/goals/arrive_at_destination.gd")
const ReturnLumber = preload("res://goap/game_logic/actions/return_lumber.gd")
const RetreatAction = preload("res://goap/game_logic/actions/retreat_action.gd")
const HideAction = preload("res://goap/game_logic/actions/hide.gd")
const GetLumber = preload("res://goap/game_logic/actions/get_lumber.gd")
const OrderAction = preload("res://goap/game_logic/actions/order_action.gd")
const WorldStateSnapshot = preload("res://tests/helpers/world_state_snapshot.gd")
const Pathfinder = preload("res://pathfind/jump_point_finder.gd")
const FsScan = preload("res://tests/helpers/fs_scan.gd")


# Strips comments so the source lint checks code, not prose about the old
# dispatch (several banners deliberately MENTION unit_arrived/on_arrive).
func _code(path: String) -> String:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var code: Array[String] = []
	for line in lines:
		var hash_index := line.find("#")
		code.append(line if hash_index < 0 else line.substr(0, hash_index))
	return "\n".join(code)


# Real Node2D double: declares the same signals as Unit (Agent._ready connects
# them all) plus the movement/combat properties the wired code touches.
class TestUnit:
	extends Node2D

	signal unit_reseted
	signal unit_idle_ended
	signal unit_stun_ended
	signal unit_attack_ended
	signal unit_attack_release
	signal unit_attack_hitted
	signal unit_death_started
	signal unit_died(unit)
	signal unit_animation_ended
	signal unit_was_attacked(attacker, damage)
	signal unit_arrived

	var moves := true
	var speed := 100.0
	var attacks := true
	var dead := false
	var team := "blue"
	var state := "idle"
	var target = null
	var last_target = null
	var attack_count := 0
	var current_modifiers: Dictionary = {}
	var current_path: Array = []
	var current_destiny := Vector2.ZERO
	var final_destiny := Vector2.ZERO
	var angle := 0.0
	var current_step := Vector2.ZERO
	var animations = null
	var channeling_timer: Timer = null
	var agent = null

	func set_state(s):
		state = s

	func mirror_look_at(_point):
		pass

	func cut_path(path):
		return path


class TestMap:
	extends Node2D
	var tile_size := 64
	var half_tile_size := 32
	var size := Vector2(320, 320)


func _make_agent(harness) -> Agent:
	var unit = TestUnit.new()
	unit.current_modifiers = Modifiers.new_modifiers()
	# GetLumber's cut channel needs a real (childed) Timer; being inside the
	# tree also lets Timer.start() actually run.
	unit.channeling_timer = Timer.new()
	unit.add_child(unit.channeling_timer)
	harness.add_child(unit)
	var agent = Agent.new()
	unit.add_child(agent)
	# The unit is inside the tree, so the engine fires Agent._ready() (and all
	# its signal connections) synchronously during this add_child. Do NOT call
	# _ready() again — that would double-connect every signal.
	unit.agent = agent
	return agent


func run(harness) -> void:
	var ws = WorldStateSnapshot.new()
	var agent = _make_agent(harness)
	var unit: TestUnit = agent.get_unit()

	# --- SOURCE LINT: no signal-based arrival dispatch anywhere ---
	harness.check(
		not _code("res://collision/collisions.gd").contains("on_arrive"),
		"Collisions drives arrival through ArriveAtDestination.advance_path (no on_arrive call)."
	)
	harness.check(
		_code("res://collision/collisions.gd").contains("advance_path"),
		"Collisions still routes arrivals through the ArriveAtDestination service."
	)
	harness.check(
		not _code("res://goap/goap_system/agent.gd").contains("unit_arrived"),
		"Agent never connects unit_arrived (arrival is a state transition, not a signal)."
	)
	harness.check(
		not _code("res://goap/goap_system/agent.gd").contains("on_arrive"),
		"Agent has no on_arrive dispatch method."
	)
	var hooked: Array[String] = []
	var scripts: Array[String] = []
	FsScan.collect("res://goap/game_logic", ".gd", scripts)
	for path in scripts:
		if _code(path).contains("func on_arrive"):
			hooked.append(path)
	harness.check(
		hooked.is_empty(),
		"No action/goal defines an on_arrive hook anymore. Offenders: %s" % [", ".join(hooked)]
	)

	# --- Regression: an arrival must NOT permanently disable WalkLane ---
	# WalkLane used to set lane_route_finished=true whenever the path was
	# empty on arrival. That fact is a hard gate in WalkLane.is_valid and has
	# no reset in normal play, so the first consumed route killed the goal
	# for good: units fought, killed an enemy, then stood still. This drives
	# the real runtime path (Collisions -> ArriveAtDestination.advance_path).
	var lane_map = TestMap.new()
	harness.add_child(lane_map)
	ws.set_state("map", lane_map)
	ws.set_state("lanes", {"mid": [Vector2(96, 96), Vector2(160, 96), Vector2(224, 96)]})
	unit.moves = true
	unit.dead = false
	unit.target = null
	unit.global_position = Vector2(224, 96)
	unit.current_path = []
	agent.set_state("lane", "mid")
	agent.erase_state("lane_route_finished")
	agent.set_state("ready_to_fight", true)
	agent.set_state("has_player_command", false)
	agent.set_state("is_retreating", false)
	agent.set_state("is_channeling", false)

	var lane_goal = Goap.get_goal("WalkLane")
	harness.check(lane_goal.is_valid(agent), "WalkLane is valid before the arrival (setup check).")
	agent._replace_plan(lane_goal, [])
	# The exact runtime state when Collisions detects the arrival for a
	# consumed route: empty path, stopped unit.
	unit.current_path = []
	unit.current_destiny = Vector2.ZERO
	Goap.get_goal("ArriveAtDestination").advance_path(unit)
	harness.check(
		not agent.get_state("lane_route_finished", false),
		"Arrival does not mark the lane route finished (that write-once fact would disable WalkLane)."
	)
	harness.check(
		lane_goal.is_valid(agent),
		"WalkLane stays valid after arrival, so the unit resumes walking instead of standing still."
	)
	# The final arrival latches the full fact set (the actions' interface).
	harness.check(
		agent.get_state("arrived_at_destination", false) == true,
		"The final arrival latches arrived_at_destination."
	)
	harness.check(
		agent.get_state("has_destiny", true) == false,
		"The final arrival clears has_destiny (no stale routing fact)."
	)
	harness.check_equal(unit.state, "idle", "The final arrival stops the unit.")
	lane_map.free()

	# --- ReturnLumber: deliver ONCE, on the FINAL arrival only ---
	var map = TestMap.new()
	harness.add_child(map)
	ws.set_state("map", map)
	ws.set_state("all_buildings", [])
	var old_grid = Navigation.path_grid
	var old_finder = Navigation.path_finder
	Navigation.path_grid = Pathfinder.GridGD.new().Grid.new(5, 5)
	Navigation.path_finder = Pathfinder.JumpPointFinder.new()

	var deliver_position := Vector2(160, 160)
	unit.global_position = Vector2(96, 96)
	unit.current_destiny = Vector2.ZERO
	unit.final_destiny = Vector2.ZERO
	unit.current_path = []
	agent.set_state("has_wood", true)
	agent.set_state("arrived_at_destination", false)
	agent.set_state("returning_wood", false)
	agent.set_state("deliver_position", deliver_position)
	ReturnLumber.new().enter(agent)

	harness.check_equal(
		unit.final_destiny,
		deliver_position,
		"ReturnLumber.enter routes the unit to deliver_position."
	)
	harness.check_equal(
		unit.state, "move", "ReturnLumber.enter starts the unit moving (no null-property assignment)."
	)
	harness.check(
		unit.current_destiny != Vector2.ZERO,
		"ReturnLumber.enter pops a real first waypoint into current_destiny."
	)
	# While travelling (no arrival yet): no delivery.
	harness.check(
		not ReturnLumber.new().perform(agent, 0.0),
		"ReturnLumber.perform does not complete before arrival."
	)
	harness.check(
		not agent.get_state("returning_wood", false),
		"ReturnLumber does not deliver before arrival."
	)
	# Final arrival: deliver exactly once.
	agent.set_state("arrived_at_destination", true)
	harness.check(
		ReturnLumber.new().perform(agent, 0.0),
		"ReturnLumber.perform completes on the final arrival."
	)
	harness.check(
		agent.get_state("returning_wood", false) == true
		and agent.get_state("has_wood", true) == false,
		"ReturnLumber delivers on the final arrival (returning_wood latch, has_wood cleared)."
	)

	# --- Retreat: arrived_at_retreat only on the FINAL arrival ---
	agent.set_state("arrived_at_retreat", false)
	agent.set_state("arrived_at_destination", false)
	harness.check(
		not RetreatAction.new().perform(agent, 0.0),
		"Retreat.perform does not complete before arrival."
	)
	agent.set_state("arrived_at_destination", true)
	harness.check(
		RetreatAction.new().perform(agent, 0.0)
		and agent.get_state("arrived_at_retreat", false) == true,
		"Retreat.perform latches arrived_at_retreat on the final arrival."
	)

	# --- Hide: hide exactly once, on the FINAL arrival ---
	agent.set_state("is_hiding", false)
	agent.set_state("arrived_at_destination", false)
	harness.check(
		not HideAction.new().perform(agent, 0.0),
		"Hide.perform does not complete before arrival."
	)
	harness.check(
		not agent.get_state("is_hiding", false),
		"Hide does not hide before arrival."
	)
	agent.set_state("arrived_at_destination", true)
	harness.check(
		not HideAction.new().perform(agent, 0.0),
		"Hide.perform starts hiding on the final arrival but waits out the timer."
	)
	harness.check(
		agent.get_state("is_hiding", false) == true and unit.visible == false,
		"Hide hides the unit on the final arrival (is_hiding latch)."
	)

	# --- GetLumber: the cut starts on the FINAL arrival, latched ---
	agent.set_state("has_wood", false)
	agent.set_state("cutting", false)
	agent.set_state("arrived_at_destination", false)
	harness.check(
		not GetLumber.new().perform(agent, 0.0),
		"GetLumber.perform does not complete before arrival."
	)
	agent.set_state("arrived_at_destination", true)
	harness.check(
		not GetLumber.new().perform(agent, 0.0),
		"GetLumber.perform starts the cut on the final arrival but awaits the channel."
	)
	harness.check(
		agent.get_state("cutting", false) == true
		and agent.get_state("has_wood", false) == false,
		"GetLumber latches cutting (has_wood arrives only after the channel)."
	)
	# exit cancels the pending cut: the continuation must not pay has_wood.
	GetLumber.new().exit(agent)
	harness.check(
		agent.get_state("cutting", false) == false,
		"GetLumber.exit cancels the pending cut."
	)
	# Session token: a re-entered cut session gets a NEW id, so an abandoned
	# coroutine can never mistake the restarted session for its own (the
	# shared channeling timer is restarted by the new session).
	var first_session: int = agent.get_state("cutting_id", 0)
	agent.set_state("arrived_at_destination", true)
	GetLumber.new().perform(agent, 0.0)  # starts a fresh cut session
	var current_session: int = agent.get_state("cutting_id", 0)
	harness.check(
		GetLumber.new()._session_is_current(agent, current_session),
		"The active cut session's token is current."
	)
	# exit() must INVALIDATE the token, not just clear the latch: the hole
	# was exit-without-re-entry -- no new session ever starts, so without the
	# bump the abandoned coroutine still saw its own id as current when the
	# timer fired and paid has_wood for a cancelled cut.
	GetLumber.new().exit(agent)
	harness.check(
		not GetLumber.new()._session_is_current(agent, current_session),
		"exit() invalidates the cut session token (exit WITHOUT re-entry kills the pending continuation)."
	)
	# A later re-entry starts yet another session; the older ones stay dead.
	agent.set_state("arrived_at_destination", true)
	GetLumber.new().perform(agent, 0.0)
	var renewed_session: int = agent.get_state("cutting_id", 0)
	harness.check(
		renewed_session > current_session,
		"GetLumber bumps the cut session token per attempt (abandoned continuations become no-ops)."
	)
	harness.check(
		not GetLumber.new()._session_is_current(agent, current_session),
		"The ABANDONED session's token is no longer current (its continuation would not pay)."
	)
	harness.check(
		GetLumber.new()._session_is_current(agent, renewed_session),
		"The CURRENT session's token still pays."
	)
	GetLumber.new().exit(agent)

	# --- Preempted arrival (goal switch before the agent turn) ---
	# The arrival fact latches during the collision tick; a goal change on
	# the agent's next turn can preempt the action before perform() consumes
	# it. The invariant: the arrival is RE-EARNED, never reused stale —
	# every migrated action re-issues movement in enter(), and movement
	# revokes the latch.
	agent.set_state("has_wood", true)
	agent.set_state("returning_wood", false)
	agent.set_state("arrived_at_destination", false)
	ReturnLumber.new().enter(agent)  # unit travels toward deliver_position
	agent.set_state("arrived_at_destination", true)  # collision latches
	# ...but a higher-priority goal preempts before perform runs:
	ReturnLumber.new().exit(agent)
	harness.check(
		not agent.get_state("returning_wood", false),
		"A preempted arrival is not delivered."
	)
	# The goal is re-selected later: re-entering revokes the stale latch.
	ReturnLumber.new().enter(agent)
	harness.check(
		agent.get_state("arrived_at_destination", true) == false,
		"Re-entering after a preemption revokes the stale arrival (it is re-earned by the new route)."
	)
	harness.check(
		not ReturnLumber.new().perform(agent, 0.0),
		"The re-entered action cannot deliver until the NEW arrival latches."
	)

	# --- Order: the conquer follow-up waits for the FINAL arrival ---
	agent.set_state("after_arive", "conquer")
	agent.set_state("arrived_at_destination", false)
	harness.check(
		OrderAction.new().perform(agent, 0.0),
		"Order.perform completes an empty order (no player_order set)."
	)
	harness.check_equal(
		agent.get_state("after_arive"), "conquer",
		"Order does NOT dispatch the conquer follow-up before arrival."
	)

	Navigation.path_grid = old_grid
	Navigation.path_finder = old_finder
	map.free()
	ws.restore()
	unit.free()
