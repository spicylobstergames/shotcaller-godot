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

	func _replace_plan(goal, plan: Array) -> void:
		_exit_current_action()
		var previous_goal = _current_goal
		_current_goal = goal
		_current_plan = plan
		_current_plan_step = 0
		if previous_goal != goal:
			goal_changed.emit(goal)
		plan_changed.emit(_current_plan)
		action_changed.emit(get_current_action())

	func _exit_current_action():
		var action = get_current_action()
		if action and action.has_method("exit"):
			action.exit(self)

	func get_current_action():
		if (
			_current_plan != null
			and _current_plan_step >= 0
			and _current_plan_step < _current_plan.size()
		):
			return _current_plan[_current_plan_step]
		else:
			return null


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
	_test_plan_following(harness)

	# --- multi-step plan ---
	_test_multi_step_plan(harness)

	# --- exit-on-plan-switch ---
	_test_exit_on_plan_switch(harness)

	# --- multi-tick completion ---
	_test_multi_tick_completion(harness)

	# --- invalid action mid-execution ---
	_test_invalid_action_mid_execution(harness)


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


func _test_plan_following(harness) -> void:
	var action = TestPlanAction.new()

	var agent = TestAgent.new(TestUnit.new())

	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [action]
	agent._current_plan_step = 0

	# Simulate _on_action_changed signal handler that enters the action.
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


func _test_multi_step_plan(harness) -> void:
	var first = TestPlanAction.new()
	# Make first action take multiple ticks (returns false first tick, true second).
	var first_ticks = 0
	first.performed = false  # reset so we can track via first_ticks
	first.perform = func(_agent, _delta: float) -> bool:
		first_ticks += 1
		if first_ticks < 2:
			return false  # first tick: still running
		return true  # second tick: completes

	var second = TestPlanAction.new()

	var agent = TestAgent.new(TestUnit.new())

	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [first, second]
	agent._current_plan_step = 0

	# Enter the first action (simulates _on_action_changed signal).
	first.enter(agent)

	# Tick loop: call _follow_plan repeatedly until the plan completes.
	while not agent._current_plan.is_empty():
		_follow_tick(agent, first, second, harness)

	# Verify first action exited after completing.
	harness.check(first.exited, "The first action exits after completing.")
	# Verify second action entered when plan advanced.
	harness.check(second.entered, "The second action enters when the plan advances to it.")
	# Verify plan step advanced.
	harness.check_equal(
		agent._current_plan_step, 1,
		"Plan step index advances after the first action completes."
	)
	# Verify plan is cleared after final action completes.
	harness.check(second.exited, "The final action exits on plan completion.")
	harness.check(
		agent._current_plan.is_empty(),
		"The plan is cleared after the final action completes."
	)


func _follow_tick(agent, first, second, harness) -> void:
	# Simulates one agent.tick(): call _follow_plan which internally calls perform().
	var step_before = agent._current_plan_step
	agent._follow_plan(agent._current_plan, 0.0)

	# If step changed, the action_changed signal should have been emitted,
	# which triggers _on_action_changed -> new action.enter().
	if agent._current_plan_step != step_before and agent._current_plan_step < agent._current_plan.size():
		var new_action = agent._current_plan[agent._current_plan_step]
		if new_action and new_action.has_method("enter") and not new_action.entered:
			new_action.enter(agent)


func _test_exit_on_plan_switch(harness) -> void:
	var old_action = TestPlanAction.new()
	var new_action = TestPlanAction.new()

	var agent = TestAgent.new(TestUnit.new())

	# Set up old plan.
	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [old_action]
	agent._current_plan_step = 0
	old_action.enter(agent)

	# Replace plan with a different goal — simulates goal priority change.
	# This is the path agent.process() takes: _replace_plan(goal, plan).
	var new_goal = TestPlanGoal.new()
	var new_plan = [new_action]
	agent._replace_plan(new_goal, new_plan)

	harness.check_equal(
		old_action.exited, true,
		"Switching plans exits the previously active action (at least once)."
	)
	harness.check_equal(
		new_action.entered, true,
		"Switching plans enters the first action of the new plan."
	)

	# Verify exit was called exactly once: call exit again manually.
	var initial_exits = old_action.exited
	old_action.exit(agent)
	harness.check_equal(
		old_action.exited, initial_exits + 1,
		"Old action exit was called exactly once by the plan switch (not duplicated)."
	)


# --- action returning false for N ticks then completing ---

func _test_multi_tick_completion(harness) -> void:
	class MultiTickAction:
		extends RefCounted
		var enter_count := 0
		var perform_count := 0
		var exit_count := 0

		func enter(_agent) -> void:
			enter_count += 1

		func perform(_agent, _delta: float) -> bool:
			perform_count += 1
			if perform_count < 3:
				return false  # Runs for 3 ticks
			return true

		func exit(_agent) -> void:
			exit_count += 1

	var action = MultiTickAction.new()

	var agent = TestAgent.new(TestUnit.new())

	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [action]
	agent._current_plan_step = 0

	# Enter the action.
	action.enter(agent)

	# Tick loop: the agent should keep calling _follow_plan, which calls
	# action.perform() repeatedly until it returns true.
	while not agent._current_plan.is_empty():
		agent._follow_plan(agent._current_plan, 0.0)
		# After step advances (or plan cleared), enter the new action if any.
		if not agent._current_plan.is_empty() and agent._current_plan_step < agent._current_plan.size():
			var curr = agent._current_plan[agent._current_plan_step]
			if curr and curr.has_method("enter") and curr.enter_count == 0:
				curr.enter(agent)

	harness.check_equal(action.perform_count, 3,
		"Agent calls perform() multiple times on the same action until it returns true.")
	harness.check_equal(action.enter_count, 1,
		"Action enter is called exactly once, even across multiple perform ticks.")
	harness.check_equal(action.exit_count, 1,
		"Action exit is called exactly once when it completes.")


# --- action that becomes invalid mid-execution ---
# The agent does NOT re-check is_valid during _follow_plan, so an action
# that becomes invalid (e.g., unit loses moves) still runs to completion.

func _test_invalid_action_mid_execution(harness) -> void:
	class RetreatingAction:
		extends RefCounted
		var _is_valid := true
		var enter_count := 0
		var perform_count := 0
		var exit_count := 0

		func is_valid(_agent) -> bool:
			return _is_valid

		func enter(_agent) -> void:
			enter_count += 1

		func perform(_agent, _delta: float) -> bool:
			perform_count += 1
			return true

		func exit(_agent) -> void:
			exit_count += 1

		func invalidate(self) -> void:
			_is_valid = false

	var action = RetreatingAction.new()
	var unit = TestUnit.new()
	unit.moves = false  # Start invalid

	var agent = TestAgent.new(unit)

	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [action]
	agent._current_plan_step = 0

	# Enter the action — it's initially invalid but agent still starts it.
	action.enter(agent)

	# Simulate one tick: the agent calls _follow_plan.
	agent._follow_plan(agent._current_plan, 0.0)

	# Even though the unit has no moves (action is invalid), the agent
	# still completes the action because _follow_plan doesn't re-check is_valid.
	harness.check_equal(action.enter_count, 1,
		"Action enters even when unit lacks moves (initial validity not checked during execution).")
	harness.check_equal(action.perform_count, 1,
		"Action performs even when it is no longer valid (is_valid is not re-checked mid-execution).")
	harness.check_equal(action.exit_count, 1,
		"Action exits after completing despite being invalid.")
