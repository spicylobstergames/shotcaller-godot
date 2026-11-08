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
	var performed := false
	var exited := false
	var _complete := false

	func _init(complete: bool = true) -> void:
		_complete = complete

	func enter(_agent: Variant) -> void:
		entered = true

	func perform(_agent: Variant, _delta: float) -> bool:
		performed = true
		return _complete

	func exit(_agent: Variant) -> void:
		exited = true


func run(harness: Node) -> void:
	# ---- Integration: full GOAP lifecycle ----
	# Tests the real Agent's _get_best_goal(), _exit_current_action(),
	# _replace_plan(), and _follow_plan() methods with mock goals and actions.

	var action_a = MockAction.new(false)  # not complete yet
	var action_b = MockAction.new(true)   # completes immediately
	var plan = [action_a, action_b]

	var goal = MockGoal.new(true, 10, plan)
	var agent = _Agent.new()
	agent._goals = [goal]
	agent._state = {}

	# --- Step 1: Goal selection ---
	var best = agent._get_best_goal()
	harness.check(best == goal, "Integration: _get_best_goal() selects the valid goal.")
	harness.check(best.prio == 10, "Integration: priority 10 > default 1.")

	# --- Step 2: Set up plan and simulate first action entry ---
	# Manually call _on_action_changed (the signal handler) instead of relying on
	# the signal connection which requires _ready() to have run.
	agent._current_plan = plan
	agent._current_plan_step = 0
	agent._on_action_changed(agent.get_current_action())
	harness.check(action_a.entered, "Integration: first action's enter() is called.")
	harness.check(action_b.entered == false, "Integration: second action has not entered yet.")

	# --- Step 3: Perform first action (not complete) ---
	var complete = action_a.perform(agent, 0.0)
	harness.check(complete == false, "Integration: first action returns false (not complete).")
	harness.check(action_a.performed, "Integration: first action's perform() was called.")

	# --- Step 4: Replace plan ---
	var action_c = MockAction.new(true)
	var new_plan = [action_c]
	var new_goal = MockGoal.new(true, 5, new_plan)

	# _replace_plan calls _exit_current_action(), emits signals, sets new plan
	agent._replace_plan(new_goal, new_plan)
	harness.check(action_a.exited, "Integration: old action's exit() is called on plan replacement.")
	agent._on_action_changed(agent.get_current_action())
	harness.check(action_c.entered, "Integration: new action's enter() is called.")
	harness.check(agent._current_goal == new_goal, "Integration: goal updated to new goal.")
	harness.check(agent._current_plan == new_plan, "Integration: plan replaced with new plan.")
	harness.check(agent._current_plan_step == 0, "Integration: plan step reset to 0.")

	# --- Step 5: Complete remaining plan ---
	agent._follow_plan(agent._current_plan, 0.0)
	harness.check(action_c.performed, "Integration: new action's perform() was called.")
	# Second follow: plan has only one step, completing it should clear
	agent._follow_plan(agent._current_plan, 0.0)
	harness.check(agent._current_plan.is_empty(), "Integration: completed plan is cleared.")
	harness.check(action_c.exited, "Integration: last action's exit() is called on plan completion.")

	agent.free()
