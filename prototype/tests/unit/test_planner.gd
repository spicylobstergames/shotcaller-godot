extends RefCounted

const Planner = preload("res://goap/goap_system/planner.gd")


# Small contract doubles let planner behavior be tested without running a real agent.
class TestAgent:
	extends RefCounted
	var state := {}

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)


class TestGoal:
	extends RefCounted
	var desired_state: Dictionary

	func _init(state: Dictionary):
		desired_state = state

	func get_desired_state(_agent) -> Dictionary:
		return desired_state


class TestAction:
	extends RefCounted
	var action_name: String
	var cost: int
	var preconditions: Dictionary
	var effects: Dictionary

	func _init(
		name: String, action_cost: int, action_preconditions: Dictionary, action_effects: Dictionary
	):
		action_name = name
		cost = action_cost
		preconditions = action_preconditions
		effects = action_effects

	func is_valid(_agent) -> bool:
		return true

	func get_cost(_agent) -> int:
		return cost

	func get_preconditions() -> Dictionary:
		return preconditions

	func get_effects() -> Dictionary:
		return effects

	func get_class_name() -> String:
		return action_name


func run(harness) -> void:
	var planner = Planner.new()
	var agent = TestAgent.new()
	var goal = TestGoal.new({"finished": true})
	var costly_action = TestAction.new("Costly", 5, {}, {"finished": true})
	var cheap_action = TestAction.new("Cheap", 1, {}, {"finished": true})
	planner.set_actions([costly_action, cheap_action])
	var cheapest_plan = planner.get_plan(agent, goal)
	harness.check_equal(cheapest_plan.size(), 1, "Planner returns a one-step solution.")
	if not cheapest_plan.is_empty():
		harness.check_equal(
			cheapest_plan[0].get_class_name(), "Cheap", "Planner selects the lowest-cost solution."
		)

	var prepare_action = TestAction.new("Prepare", 1, {}, {"ready": true})
	var finish_action = TestAction.new("Finish", 1, {"ready": true}, {"finished": true})
	# List the dependent action first to verify planning follows preconditions, not registry order.
	planner.set_actions([finish_action, prepare_action])
	var ordered_plan = planner.get_plan(agent, goal)
	harness.check_equal(ordered_plan.size(), 2, "Planner resolves action preconditions.")
	if ordered_plan.size() == 2:
		harness.check_equal(
			ordered_plan[0].get_class_name(),
			"Prepare",
			"Prerequisite action is planned before its dependent action."
		)
		harness.check_equal(
			ordered_plan[1].get_class_name(), "Finish", "Goal-producing action is planned last."
		)

	planner.set_actions([])
	harness.check(
		planner.get_plan(agent, goal).is_empty(),
		"Planner returns no plan when no action can satisfy the goal."
	)
