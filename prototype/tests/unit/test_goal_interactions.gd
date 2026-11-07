extends RefCounted

const GoalContract = preload("res://goap/goap_system/goal_contract.gd")
var _Agent = load("res://goap/goap_system/agent.gd")


# Mock goal that extends GoalContract so production code paths (is_valid,
# priority) are exercised rather than a hand-rolled implementation.
class MockGoal extends GoalContract:
	var valid: bool = true
	var prio: int = 1
	var valid_calls: int = 0
	var priority_calls: int = 0
	var on_valid: Callable = Callable()

	func _init(v: bool = true, p: int = 1) -> void:
		valid = v
		prio = p

	func is_valid(_agent: Variant) -> bool:
		valid_calls += 1
		if not on_valid.is_null():
			on_valid.call()
		if not valid:
			return false
		return true

	func priority(_agent: Variant) -> int:
		priority_calls += 1
		return prio


# Helper to set up an agent with injected goals and a goal tracker.
# Returns [agent, recorder] where recorder.goals is populated by signals.
func _setup(goals: Array) -> Array:
	var agent = _Agent.new()
	agent._goals = goals  # inject mock goals directly

	var recorder = {"goals": []}
	agent.goal_changed.connect(func(g): recorder.goals.append(g))

	return [agent, recorder]


func run(harness: Node) -> void:
	# ---- 1. equal-priority tie-breaking ----
	# Production uses > (strict), so the *first* inserted goal wins ties.
	var m1 := MockGoal.new(true, 5)
	var m2 := MockGoal.new(true, 5)
	var setup_result = _setup([m1, m2])
	var agent = setup_result[0]
	var recorder = setup_result[1]
	var best = agent._get_best_goal()
	harness.check(best == m1, "Equal-priority: first inserted goal wins (strict > in _get_best_goal).")
	harness.check(m1.valid_calls >= 1, "Equal-priority: first goal's is_valid() was called.")
	harness.check(m2.valid_calls >= 1, "Equal-priority: second goal's is_valid() was called.")
	agent.free()

	# ---- 2. no valid goals ----
	var invalid_goal := MockGoal.new(false, 10)
	var setup_result2 = _setup([invalid_goal])
	var agent2 = setup_result2[0]
	var recorder2 = setup_result2[1]
	best = agent2._get_best_goal()
	harness.check(best == null, "No valid goals: _get_best_goal() returns null.")
	agent2.free()

	# ---- 3. is_valid() side effects ----
	# The first goal is invalid but has a side-effect that makes the second
	# goal valid, exercising the callback path inside is_valid().
	var flag = {"second_valid": false}
	var side_effect = func(): flag.second_valid = true

	var inv := MockGoal.new(false, 3)
	inv.on_valid = side_effect

	var valid := MockGoal.new(false, 3)  # initially invalid
	var setup_result3 = _setup([inv, valid])
	var agent3 = setup_result3[0]
	var recorder3 = setup_result3[1]
	best = agent3._get_best_goal()

	harness.check(flag.second_valid, "is_valid() side effect fired during iteration.")
	harness.check(inv.valid_calls >= 1, "is_valid side-effects: invalid goal was evaluated.")

	# The original invalid goal returns false, so it is skipped.
	# The second goal is *still* invalid (side-effect only set flag, did not change mock state).
	harness.check(best == null, "is_valid side-effect: second mock goal remains invalid (no state mutation in mock).")
	agent3.free()

	# ---- 4. priority changes while valid ----
	var prio_a := MockGoal.new(true, 5)
	var prio_b := MockGoal.new(true, 3)
	var setup_result4 = _setup([prio_a, prio_b])
	var agent4 = setup_result4[0]
	var recorder4 = setup_result4[1]

	best = agent4._get_best_goal()
	harness.check(best == prio_a, "Priority change: higher-priority goal (A=5) is selected first.")

	# B's priority increases above A's while A is still valid
	prio_b.prio = 10
	best = agent4._get_best_goal()
	harness.check(best == prio_b, "Priority change: _get_best_goal() reflects updated priority (B=10 > A=5).")

	# A's priority increases above B's
	prio_a.prio = 15
	best = agent4._get_best_goal()
	harness.check(best == prio_a, "Priority change: A regains lead (A=15 > B=10).")
	agent4.free()
