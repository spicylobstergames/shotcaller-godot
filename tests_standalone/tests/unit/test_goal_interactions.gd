extends RefCounted

const Agent = preload("res://goap/goap_system/agent.gd")


# Lightweight mock goal using RefCounted — same is_valid / priority contract
# that the production Agent._get_best_goal() evaluates.
class MockGoal:
	extends RefCounted
	var valid: bool
	var prio: int
	var valid_calls: int
	var priority_calls: int
	var on_valid: Callable

	func _init(v: bool = true, p: int = 1) -> void:
		valid = v
		prio = p
		valid_calls = 0
		priority_calls = 0
		on_valid = Callable()

	func is_valid(_agent) -> bool:
		valid_calls += 1
		# Fire side-effect callback before checking validity, so tests can
		# exercise callbacks even on invalid goals (the callback runs during
		# the is_valid() call, not after it).
		if not on_valid.is_null():
			on_valid.call()
		if not valid:
			return false
		return true

	func priority(_agent) -> int:
		priority_calls += 1
		return prio


# Create an Agent, inject mock goals into its private _goals array, wire up
# the goal_changed signal, and return [agent, recorder].
# (Agent._ready() is intentionally NOT called — it needs a _unit parent.)
func _setup(goals: Array) -> Array:
	var agent = Agent.new()
	agent._goals = goals
	var recorder = {"goals": []}
	agent.goal_changed.connect(func(g): recorder.goals.append(g))
	return [agent, recorder]


func run(harness: Node) -> void:
	# ── 1. equal-priority tie-breaking ──────────────────────────────
	# The production loop uses > (strict), so the first goal with the
	# highest priority wins when priorities are equal.
	var m1 = MockGoal.new(true, 5)
	var m2 = MockGoal.new(true, 5)
	var setup1 = _setup([m1, m2])
	var agent1 = setup1[0]
	var best1 = agent1._get_best_goal()

	harness.check(best1 == m1, "Equal-priority: first inserted goal wins (strict > in _get_best_goal).")
	harness.check(m1.valid_calls >= 1, "Equal-priority: first goal is_valid() called.")
	harness.check(m2.valid_calls >= 1, "Equal-priority: second goal is_valid() called.")
	agent1.free()

	# ── 2. no valid goals ──────────────────────────────────────────
	var invalid = MockGoal.new(false, 10)
	var setup2 = _setup([invalid])
	var agent2 = setup2[0]
	var best2 = agent2._get_best_goal()

	harness.check(best2 == null, "No valid goals: _get_best_goal() returns null.")
	agent2.free()

	# ── 3. is_valid() side effects ─────────────────────────────────
	# The first goal is invalid but has an on_valid callback that fires
	# during is_valid() iteration.  The second goal is also invalid;
	# the side-effect only sets a flag (it does not mutate the mock),
	# so the final best goal is still null — verifying the callback ran.
	var flag = {"side_effect_fired": false}
	var side_effect = func(): flag.side_effect_fired = true

	var inv = MockGoal.new(false, 3)
	inv.on_valid = side_effect
	var goal2 = MockGoal.new(false, 3)
	var setup3 = _setup([inv, goal2])
	var agent3 = setup3[0]
	var best3 = agent3._get_best_goal()

	harness.check(flag.side_effect_fired, "is_valid() side effect fired during iteration.")
	harness.check(inv.valid_calls >= 1, "is_valid side-effects: invalid goal was evaluated.")
	harness.check(best3 == null, "is_valid side-effect: second mock goal remains invalid (no state mutation).")
	agent3.free()

	# ── 4. priority changes while valid ────────────────────────────
	var prio_a = MockGoal.new(true, 5)
	var prio_b = MockGoal.new(true, 3)
	var setup4 = _setup([prio_a, prio_b])
	var agent4 = setup4[0]

	var best4 = agent4._get_best_goal()
	harness.check(best4 == prio_a, "Priority change: higher-priority goal (A=5) selected first.")

	# B's priority rises above A's while A is still valid
	prio_b.prio = 10
	best4 = agent4._get_best_goal()
	harness.check(best4 == prio_b, "Priority change: _get_best_goal() reflects updated priority (B=10 > A=5).")

	# A's priority rises above B's
	prio_a.prio = 15
	best4 = agent4._get_best_goal()
	harness.check(best4 == prio_a, "Priority change: A regains lead (A=15 > B=10).")
	agent4.free()
