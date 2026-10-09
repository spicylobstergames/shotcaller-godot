extends Node

const Agent = preload("res://goap/goap_system/agent.gd")


class TestGoal:
	extends RefCounted


class TestAction:
	extends RefCounted

	var completes := false
	var enter_count := 0
	var exit_count := 0

	func enter(_agent) -> void:
		enter_count += 1

	func perform(_agent, _delta: float) -> bool:
		return completes

	func exit(_agent) -> void:
		exit_count += 1


class SignalRecorder:
	extends RefCounted

	var goals: Array = []
	var plans: Array = []
	var actions: Array = []

	func on_goal_changed(goal) -> void:
		goals.append(goal)

	func on_plan_changed(plan) -> void:
		plans.append(plan.duplicate())

	func on_action_changed(action) -> void:
		actions.append(action)


func run(harness) -> void:
	var agent = Agent.new()
	var recorder = SignalRecorder.new()
	var goal = TestGoal.new()
	var first_action = TestAction.new()
	var second_action = TestAction.new()

	agent.action_changed.connect(agent._on_action_changed)
	agent.goal_changed.connect(recorder.on_goal_changed)
	agent.plan_changed.connect(recorder.on_plan_changed)
	agent.action_changed.connect(recorder.on_action_changed)

	agent._replace_plan(goal, [first_action, second_action])
	harness.check_equal(recorder.goals, [goal], "Agent emits a goal change for the selected goal.")
	harness.check_equal(recorder.plans.size(), 1, "Agent emits the newly assigned plan.")
	harness.check_equal(
		recorder.actions, [first_action], "Agent emits and enters the first planned action."
	)
	harness.check_equal(first_action.enter_count, 1, "The first action enters when selected.")

	first_action.completes = true
	agent._follow_plan(agent._current_plan, 0.0)
	harness.check_equal(first_action.exit_count, 1, "Completed action exits before advancing.")
	harness.check_equal(second_action.enter_count, 1, "The next action enters after advancement.")
	harness.check_equal(
		recorder.actions, [first_action, second_action], "Agent emits each action transition."
	)

	second_action.completes = true
	agent._follow_plan(agent._current_plan, 0.0)
	harness.check_equal(recorder.goals, [goal, null], "Completing the plan emits the cleared goal.")
	harness.check_equal(
		recorder.plans.back(), [], "Completing the plan emits the empty replacement plan."
	)
	harness.check_equal(
		recorder.actions,
		[first_action, second_action, null],
		"Completing the plan clears the active action."
	)
	harness.check_equal(second_action.exit_count, 1, "The final action exits on plan completion.")

	agent.free()
