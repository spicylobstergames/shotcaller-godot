extends RefCounted

# Agent execution history (PR #239 feedback): a bounded per-agent log of
# goal/plan/action transitions plus the movement/service sub-events actions
# trigger, so tests (and freeze_report) can verify that a unit performs the
# EXPECTED SEQUENCE, e.g.
#   EnemyDefeated: goal > plan:ChooseTarget, PursueEnemy, AttackEnemy
#                  > action records > navigate_request/move_request
#                  > melee_hit/range_release
# The history is diagnostics only: nothing in planning or execution reads it.
# These tests pin the recording points, the ring-buffer bound, per-agent
# isolation, and the reset contract.

const Agent = preload("res://goap/goap_system/agent.gd")
const ArriveAtDestination = preload("res://goap/game_logic/goals/arrive_at_destination.gd")


# Real Node double: declares the same signals as Unit (Agent._ready connects
# them all) plus the movement properties the wired code touches.
class TestUnit:
	extends Node

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
	var attack_count := 0
	var current_modifiers: Dictionary = {}
	var current_path: Array = []
	var current_destiny := Vector2.ZERO
	var final_destiny := Vector2.ZERO
	var global_position := Vector2.ZERO
	var angle := 0.0
	var current_step := Vector2.ZERO
	var animations = null
	var agent = null

	func set_state(s):
		state = s

	func mirror_look_at(_point):
		pass

	func cut_path(path):
		return path


class TestAction:
	extends RefCounted
	var name := "TestAction"
	var completes := false

	func _init(action_name := "TestAction"):
		name = action_name

	func get_class_name() -> String:
		return name

	func enter(_agent) -> void:
		pass

	func perform(_agent, _delta: float) -> bool:
		return completes

	func exit(_agent) -> void:
		pass


class TestGoal:
	extends RefCounted

	func is_valid(_agent) -> bool:
		return true

	func priority(_agent) -> int:
		return 1

	func get_desired_state(_agent) -> Dictionary:
		return {"history_probe": true}

	func enter(_agent) -> void:
		pass

	func exit(_agent) -> void:
		pass

	func get_class_name() -> String:
		return "TestGoal"


func _make_agent() -> Agent:
	var unit = TestUnit.new()
	unit.current_modifiers = Modifiers.new_modifiers()
	var agent = Agent.new()
	unit.add_child(agent)
	# add_child on a detached subtree does not fire _ready; run the production
	# wiring explicitly (same pattern as test_arrival_dispatch).
	agent._ready()
	unit.agent = agent
	return agent


func run(harness) -> void:
	# --- goal / plan / action transitions are recorded in order ---
	var agent = _make_agent()
	var goal = TestGoal.new()
	var first = TestAction.new("First")
	var second = TestAction.new("Second")
	agent._replace_plan(goal, [first, second])
	var summary := agent.history_summary()
	harness.check(summary.has("goal:TestGoal"),
		"A goal change is recorded." )
	harness.check(summary.has("plan:First, Second"),
		"A plan install records the plan shape (action names in order).")
	harness.check(summary.has("action:First"),
		"The first planned action is recorded (and entered).")

	first.completes = true
	agent._follow_plan(agent._current_plan, 0.0)
	summary = agent.history_summary()
	harness.check(summary.has("action:Second"),
		"Advancing a completed step records the next action.")
	harness.check(summary.has("completed:First"),
		"A completed action is recorded explicitly (distinct from entering it).")
	harness.check(
		summary.find("action:First") < summary.find("completed:First")
		and summary.find("completed:First") < summary.find("action:Second"),
		"History order: enter action -> completed action -> enter next action."
	)

	# --- plan completion clears the goal and records it ---
	second.completes = true
	agent._follow_plan(agent._current_plan, 0.0)  # completes the plan
	harness.check(agent.history_summary().has("goal:NONE"),
		"Completing a plan records the cleared goal.")

	# --- record_event bounds the buffer (oldest dropped) ---
	for i in range(agent.HISTORY_LIMIT + 5):
		agent.record_event("probe", i)
	harness.check_equal(
		agent.history.size(), agent.HISTORY_LIMIT,
		"The history is capped at HISTORY_LIMIT entries."
	)
	harness.check_equal(
		agent.history[0]["detail"], 5,
		"The OLDEST entries are dropped (first probe kept is 5)."
	)

	# --- get_history returns a copy ---
	var snapshot := agent.get_history()
	snapshot.append({"kind": "tamper", "detail": null})
	harness.check(
		not agent.history.has({"kind": "tamper", "detail": null}),
		"get_history returns a copy; callers cannot mutate the log."
	)

	# --- history_summary honours its limit ---
	harness.check_equal(
		agent.history_summary(3).size(), 3,
		"history_summary(limit) returns at most the last `limit` entries."
	)

	# --- reset clears the log and starts a fresh one ---
	agent.reset()
	summary = agent.history_summary()
	harness.check_equal(summary.size(), 1,
		"reset() clears the history (per-life log).")
	harness.check(summary[0].begins_with("reset:"),
		"reset() records itself as the first event of the new life.")

	# --- per-agent isolation ---
	var other = _make_agent()
	other.record_event("only_on_other", true)
	harness.check(
		not agent.history_summary().has("only_on_other:true"),
		"Two agents never share history entries."
	)

	# --- movement sub-events: Move.move and Navigate.follow_path ---
	agent.set_state("is_stunned", false)
	Goap.get_action("Move").move(agent.get_unit(), Vector2(64, 64))
	Goap.get_action("Navigate").follow_path(
		agent.get_unit(), [Vector2(128, 64), Vector2(192, 64)]
	)
	summary = agent.history_summary()
	harness.check(summary.has("move_request:" + str(Vector2(64, 64))),
		"Move.move records a move_request sub-event.")
	harness.check(summary.has("navigate_request:" + str(Vector2(128, 64))),
		"Navigate.follow_path records a navigate_request sub-event (the waypoint).")

	# --- arrival sub-events: waypoint advance vs FINAL arrival ---
	var arrive_goal = ArriveAtDestination.new()
	var unit = agent.get_unit()
	unit.current_path = [Vector2(192, 64)]
	arrive_goal.advance_path(unit)
	# The waypoint record carries the destiny just reached; on_arrive then
	# advances the path (which logs its own navigate/move_request records).
	harness.check(
		agent.history_summary().has("waypoint:" + str(Vector2(128, 64))),
		"A mid-path arrival records a waypoint advance (not the final fact)."
	)
	unit.current_path = []
	arrive_goal.advance_path(unit)
	harness.check(agent.history_summary().back().begins_with("arrive:"),
		"The final arrival (empty path) records the arrive event.")
	harness.check(
		agent.get_state("arrived_at_destination", false) == true,
		"The final arrival still latches arrived_at_destination."
	)

	other.free()
	unit.free()
