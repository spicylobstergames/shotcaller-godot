extends RefCounted

const GoalContract = preload("res://goap/goap_system/goal_contract.gd")
var _Agent = load("res://goap/goap_system/agent.gd")


# --- Mock Goal ---

class MockGoal extends GoalContract:
	var valid: bool = true
	var prio: int = 1
	var plan: Array = []

	func _init(v: bool, p: int, actions: Array = []) -> void:
		valid = v
		prio = p
		plan = actions

	func is_valid(_agent: Variant) -> bool:
		return valid

	func priority(_agent: Variant) -> int:
		return prio

	func get_plan(_agent: Variant) -> Array:
		return plan


# --- Mock Action ---

class MockAction extends RefCounted:
	var entered := false
	var perform_count := 0
	var exited := false
	var _ticks_to_complete := 1

	func _init(ticks: int = 1) -> void:
		_ticks_to_complete = ticks

	func enter(_agent: Variant) -> void:
		entered = true

	func perform(_agent: Variant, _delta: float) -> bool:
		perform_count += 1
		return perform_count >= _ticks_to_complete

	func exit(_agent: Variant) -> void:
		exited = true


func run(harness: Node) -> void:
	# ---- Integration: real Agent's signal wiring and plan lifecycle ----
	# The Agent's _ready() normally connects action_changed → _on_action_changed.
	# Here we replicate that connection since _ready() can't run without a scene tree.

	# --- Test 1: goal selection ---
	var action_a = MockAction.new(2)  # takes 2 ticks to complete
	var plan = [action_a]
	var goal = MockGoal.new(true, 10, plan)
	var agent = _Agent.new()
	agent._goals = [goal]
	agent._state = {}
	agent.action_changed.connect(agent._on_action_changed)

	var best = agent._get_best_goal()
	harness.check(best == goal, "Goal selection: real Agent picks the valid goal.")
	harness.check(best.prio == 10, "Goal selection: priority 10 beats default 1.")

	# --- Test 2: multi-step plan with real Agent lifecycle ---
	var first = MockAction.new(1)  # completes in 1 tick
	var second = MockAction.new(1)  # completes in 1 tick
	var plan2 = [first, second]
	var goal2 = MockGoal.new(true, 5, plan2)
	var agent2 = _Agent.new()
	agent2._goals = [goal2]
	agent2._state = {}
	agent2.action_changed.connect(agent2._on_action_changed)

	# Set up plan (simulates what process() + _replace_plan do)
	agent2._current_plan = plan2
	agent2._current_plan_step = 0
	agent2._current_goal = goal2

	# First action enters via signal
	agent2.action_changed.emit(agent2.get_current_action())
	harness.check(first.entered, "Lifecycle: first action enters when plan is set.")
	harness.check(second.entered == false, "Lifecycle: second action not entered yet.")

	# First tick: first action performs (completes immediately), advances to second
	agent2._follow_plan(agent2._current_plan, 0.0)
	harness.check(first.exited, "Lifecycle: first action exits after completing.")
	harness.check(first.perform_count == 1, "Lifecycle: first action perform() called once.")
	harness.check(second.entered, "Lifecycle: second action enters when plan advances.")
	harness.check(agent2._current_plan_step == 1, "Lifecycle: plan step advanced to second action.")

	# Second tick: second action completes, plan is cleared
	agent2._follow_plan(agent2._current_plan, 0.0)
	harness.check(second.exited, "Lifecycle: last action exits after completing.")
	harness.check(second.perform_count == 1, "Lifecycle: second action perform() called once.")
	harness.check(agent2._current_plan.is_empty(), "Lifecycle: completed plan is cleared.")

	# --- Test 3: plan replacement with real Agent ---
	var action_b = MockAction.new(1)
	var new_plan = [action_b]
	var new_goal = MockGoal.new(true, 8, new_plan)

	agent2._replace_plan(new_goal, new_plan)
	harness.check(agent2._current_goal == new_goal, "Replacement: goal updated.")
	harness.check(agent2._current_plan == new_plan, "Replacement: plan replaced.")
	harness.check(agent2._current_plan_step == 0, "Replacement: step reset to 0.")
	harness.check(action_b.entered, "Replacement: new action entered via signal.")

	agent2._follow_plan(agent2._current_plan, 0.0)
	harness.check(action_b.exited, "Replacement: completed action exits.")
	harness.check(agent2._current_plan.is_empty(), "Replacement: plan cleared after completion.")

	# --- Test 4: multi-tick action with real Agent ---
	var multi = MockAction.new(3)  # takes 3 ticks
	var plan3 = [multi]
	var agent3 = _Agent.new()
	agent3._goals = [goal]  # reuse goal
	agent3._state = {}
	agent3.action_changed.connect(agent3._on_action_changed)
	agent3._current_plan = plan3
	agent3._current_plan_step = 0
	agent3.action_changed.emit(agent3.get_current_action())

	for i in range(3):
		agent3._follow_plan(agent3._current_plan, 0.0)

	harness.check_equal(multi.perform_count, 3,
		"Multi-tick: perform() called exactly 3 times.")
	harness.check_equal(multi.enter_count, 1,
		"Multi-tick: enter() called exactly once.")
	harness.check_equal(multi.exit_count, 1,
		"Multi-tick: exit() called exactly once.")
	harness.check(multi.exited, "Multi-tick: action exits after final tick.")

	agent.free()
	agent2.free()
	agent3.free()
