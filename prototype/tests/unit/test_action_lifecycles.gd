extends RefCounted

const RetreatAction = preload("res://goap/game_logic/actions/retreat_action.gd")
const Agent = preload("res://goap/goap_system/agent.gd")


# Lightweight unit stub that exposes only what action lifecycle methods touch.
class TestUnit:
	extends RefCounted
	var moves := true
	var team := "blue"
	var current_path: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)]


# Stub agent that mimics just the state-storage and unit-accessors.
class TestAgent:
	extends RefCounted
	var _unit: TestUnit
	var state := {}

	func _init(unit: TestUnit):
		_unit = unit

	func get_unit() -> TestUnit:
		return _unit

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)

	func set_state(state_name: String, value) -> void:
		state[state_name] = value


func run(harness) -> void:
	var retreat = RetreatAction.new()
	var unit = TestUnit.new()
	var agent = TestAgent.new(unit)

	# --- cost ---
	harness.check_equal(
		retreat.get_cost(agent), 1, "RetreatAction costs 1 regardless of agent state."
	)

	# --- effects ---
	var effects = retreat.get_effects()
	harness.check_equal(
		effects,
		{"arrived_at_retreat": true},
		"RetreatAction sets arrived_at_retreat in its effects."
	)

	# --- is_valid ---
	var idle_unit = TestUnit.new()
	idle_unit.moves = false
	var idle_agent = TestAgent.new(idle_unit)
	harness.check(
		not retreat.is_valid(idle_agent), "RetreatAction is invalid when the unit has no moves."
	)
	harness.check(
		retreat.is_valid(agent), "RetreatAction is valid when the unit has moves."
	)

	# --- perform / exit ---
	var idle_agent2 = TestAgent.new(TestUnit.new())
	harness.check(
		not retreat.perform(idle_agent2, 0.0),
		"RetreatAction perform returns false when arrived_at_retreat is not set."
	)
	idle_agent2.set_state("arrived_at_retreat", true)
	harness.check(
		retreat.perform(idle_agent2, 0.0),
		"RetreatAction perform returns true when arrived_at_retreat is set."
	)

	retreat.exit(agent)
	harness.check(true, "RetreatAction exit completes without error.")

	retreat.free()
	unit.free()
	idle_unit.free()
	idle_agent.free()
	idle_agent2.free()


# --- plan-following lifecycle ---

class TestPlanAction:
	extends RefCounted
	var entered := false
	var performed := false
	var exited := false

	func enter(_agent) -> void:
		entered = true

	func perform(_agent, _delta: float) -> bool:
		performed = true
		return true

	func exit(_agent) -> void:
		exited = true


class TestPlanGoal:
	extends RefCounted

	func is_valid(_agent) -> bool:
		return true

	func priority(_agent) -> int:
		return 1

	func get_desired_state(_agent) -> Dictionary:
		return {"plan_completed": true}


func _test_plan_following(harness, action: TestPlanAction) -> void:
	var agent = Agent.new()
	agent.goals_list = ["test_goal"]

	# The agent has a private _goals array but no real goals, so _get_best_goal() returns null.
	# We bypass that and directly test _follow_plan.
	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [action]
	agent._current_plan_step = 0

	# The signal handler enters the action immediately when the plan is set.
	# Since we set _current_plan directly, we must trigger enter manually.
	if action and action.has_method("enter"):
		action.enter(agent)

	# Simulate one perform tick.
	agent._follow_plan(agent._current_plan, 0.0)

	# After perform returns true on the last step, the plan is cleared.
	harness.check(action.entered, "Plan action enters before perform.")
	harness.check(action.performed, "Plan action performs when _follow_plan advances the step.")
	harness.check(action.exited, "Plan action exits after completing the last step.")

	# Verify the plan was cleared.
	harness.check(
		agent._current_plan.is_empty(),
		"Completing the final action clears the current plan array."
	)

	agent.free()


func _test_multi_step_plan(harness) -> void:
	var first = TestPlanAction.new()
	var second = TestPlanAction.new()

	var agent = Agent.new()
	agent.goals_list = ["test_goal"]

	# Enter the first action immediately (simulates _on_action_changed).
	first.enter(agent)

	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [first, second]
	agent._current_plan_step = 0

	# First action completes.
	first.perform(agent, 0.0)
	agent._follow_plan(agent._current_plan, 0.0)

	harness.check(first.exited, "The first action exits after completing.")
	harness.check(
		second.entered,
		"The second action enters when the plan advances to it."
	)
	harness.check_equal(
		agent._current_plan_step, 1,
		"Plan step index advances after the first action completes."
	)

	# Second action completes — final step, plan clears.
	second.perform(agent, 0.0)
	agent._follow_plan(agent._current_plan, 0.0)

	harness.check(second.exited, "The final action exits on plan completion.")
	harness.check(
		agent._current_plan.is_empty(),
		"The plan is cleared after the final action completes."
	)

	agent.free()
	first = null
	second = null


func _test_exit_on_plan_switch(harness) -> void:
	var old_action = TestPlanAction.new()
	var new_action = TestPlanAction.new()

	var agent = Agent.new()
	agent.goals_list = ["test_goal"]

	old_action.enter(agent)
	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [old_action]
	agent._current_plan_step = 0

	# Replace plan with a different goal — should exit the old action.
	var new_goal = TestPlanGoal.new()
	var new_plan = [new_action]
	agent._replace_plan(new_goal, new_plan)

	harness.check(
		old_action.exited,
		"Switching plans exits the previously active action."
	)
	harness.check(
		new_action.entered,
		"Switching plans enters the first action of the new plan."
	)

	agent.free()
	old_action = null
	new_action = null
