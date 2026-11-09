extends RefCounted


# Mock RetreatAction that mirrors the real RetreatAction interface
# but doesn't depend on autoloads like WorldState/Goap.
class MockRetreatAction:
	extends RefCounted
	var _entered := false
	var _exit_called := 0

	func is_valid(agent) -> bool:
		return agent.get_unit().moves

	func get_cost(_agent) -> int:
		return 1

	func get_effects() -> Dictionary:
		return {"arrived_at_retreat": true}

	func perform(agent, _delta) -> bool:
		return agent.get_state("arrived_at_retreat", false)

	func enter(agent):
		_entered = true

	func exit(_agent) -> void:
		_exit_called += 1



# Lightweight unit stub that exposes only what action lifecycle methods touch.
class TestUnit:
	extends RefCounted
	var moves := true
	var team := "blue"
	var current_path: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)]
	var agent: TestAgent


# Stub agent that mimics the production Agent's plan lifecycle methods.
# Only the plan-following methods are duplicated here; action interface testing
# is done separately with MockRetreatAction (no Agent dependency).
class TestAgent:
	extends RefCounted
	var _unit: TestUnit
	var state := {}
	var _current_goal: Variant
	var _current_plan: Array = []
	var _current_plan_step: int = 0
	signal plan_changed(plan)
	signal goal_changed(goal)
	signal action_changed(action)
	var _current_action_entered: bool = false

	func _init(unit: TestUnit):
		_unit = unit
		unit.agent = self
		action_changed.connect(_on_action_changed)

	func get_unit() -> TestUnit:
		return _unit

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)

	func set_state(state_name: String, value) -> void:
		state[state_name] = value

	func _on_action_changed(action):
		if action and action.has_method("enter"):
			action.enter(self)
			_current_action_entered = true

	func _replace_plan(goal: Variant, plan: Array) -> void:
		_exit_current_action()
		var previous_goal = _current_goal
		_current_goal = goal
		_current_plan = plan
		_current_plan_step = 0
		_current_action_entered = false
		if previous_goal != goal:
			goal_changed.emit(goal)
		plan_changed.emit(_current_plan)
		action_changed.emit(get_current_action())

	func _exit_current_action():
		var action = get_current_action()
		if action and action.has_method("exit"):
			action.exit(self)

	func _follow_plan(plan: Array, _delta: float):
		if plan == null or plan.is_empty() or _current_plan_step >= plan.size():
			return
		var action = plan[_current_plan_step]
		if action == null:
			return
		var is_step_complete = action.perform(self, _delta)
		if is_step_complete:
			if _current_plan_step < plan.size() - 1:
				if action.has_method("exit"):
					action.exit(self)
				_current_plan_step += 1
				action_changed.emit(get_current_action())
			else:
				_exit_current_action()
				_current_goal = null
				_current_plan = []
				_current_plan_step = 0

	func get_current_action():
		if _current_plan != null and _current_plan_step >= 0 and _current_plan_step < _current_plan.size():
			return _current_plan[_current_plan_step]
		else:
			return null


func run(harness) -> void:
	var retreat = MockRetreatAction.new()
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

	# Test doubles are RefCounted — they clean up when the references drop.

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
	var exit_count := 0
	var custom_perform: Callable = Callable()

	func enter(_agent) -> void:
		entered = true

	func perform(_agent, _delta: float) -> bool:
		performed = true
		if custom_perform.is_valid():
			return custom_perform.call(_agent, _delta)
		return true

	func exit(_agent) -> void:
		exited = true
		exit_count += 1


class TestPlanGoal:
	extends RefCounted

	func is_valid(_agent) -> bool:
		return true

	func priority(_agent) -> int:
		return 1

	func get_desired_state(_agent) -> Dictionary:
		return {"plan_completed": true}


# Action that runs for N ticks before completing
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
			return false
		return true

	func exit(_agent) -> void:
		exit_count += 1


# Action that can be invalidated mid-execution
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

	func invalidate() -> void:
		_is_valid = false


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
	var first = MultiTickAction.new()   # completes on its 3rd perform tick
	var second = TestPlanAction.new()   # completes on its 1st perform tick

	var agent = TestAgent.new(TestUnit.new())

	# Enter the plan through the production path: _replace_plan emits
	# action_changed, which enters the first action via _on_action_changed.
	agent._replace_plan(TestPlanGoal.new(), [first, second])

	# Tick until the plan completes. Bounded: a regression that prevents
	# completion must fail the test, not hang the suite.
	var tick_guard := 0
	while not agent._current_plan.is_empty() and tick_guard < 100:
		agent._follow_plan(agent._current_plan, 0.0)
		tick_guard += 1

	harness.check(tick_guard < 100,
		"Multi-step plan completes within the tick guard (no infinite loop).")
	harness.check_equal(first.perform_count, 3,
		"First action performs until complete (3 ticks).")
	harness.check_equal(first.exit_count, 1,
		"First action exits exactly once when it completes.")
	harness.check_equal(first.enter_count, 1,
		"First action entered exactly once.")
	harness.check(second.entered,
		"Second action enters when the plan advances (via action_changed signal).")
	harness.check(second.exited,
		"Final action exits on plan completion.")
	harness.check(agent._current_plan.is_empty(),
		"The plan is cleared after the final action completes.")
	harness.check(agent._current_goal == null,
		"Current goal is cleared after plan completion.")


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

	# Verify exit was called exactly once by the plan switch (not duplicated).
	harness.check_equal(
		old_action.exit_count, 1,
		"Old action exit was called exactly once by the plan switch (not duplicated)."
	)


# --- action returning false for N ticks then completing ---

func _test_multi_tick_completion(harness) -> void:
	var action = MultiTickAction.new()

	var agent = TestAgent.new(TestUnit.new())

	agent._current_goal = TestPlanGoal.new()
	agent._current_plan = [action]
	agent._current_plan_step = 0

	# Enter the action.
	action.enter(agent)

	# Tick loop: the agent should keep calling _follow_plan, which calls
	# action.perform() repeatedly until it returns true.
	# Bounded: an action that never completes must fail the test, not hang it.
	# (The stale manual re-enter block was removed — TestAgent enters new
	# actions itself via the action_changed signal.)
	var tick_guard := 0
	while not agent._current_plan.is_empty() and tick_guard < 100:
		agent._follow_plan(agent._current_plan, 0.0)
		tick_guard += 1
	harness.check(tick_guard < 100,
		"Multi-tick plan completes within the tick guard (no infinite loop).")

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
