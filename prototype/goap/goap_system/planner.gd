extends Node

# self = GoapActionPlanner
var _actions: Array


# Set actions available for planning.
# This can be changed at runtime for more dynamic options.
func set_actions(actions: Array):
	_actions = actions


# Receives a goal and returns a list of actions to be executed.
func get_plan(agent, goal) -> Array:
	var desired_state: Dictionary = goal.get_desired_state(agent)

	if desired_state.is_empty():
		return []
	return _find_best_plan(goal, desired_state, agent)


func _find_best_plan(goal, desired_state: Dictionary, agent):
	# Goal is set as root action.
	var root = {
		"action": goal,
		"state": desired_state,
		"children": [],
	}

	# Build plans will populate root with children.
	# In case it doesn't find a valid path, it will return false.
	if _build_plans(root, agent):
		var plans = _transform_tree_into_array(root, agent)

		if plans.is_empty():
			push_error("goap action planner error: no valid plans")
			return []

		return _get_cheapest_plan(plans)

	return []


# Compares plan cost and returns the actions included in the cheapest one.
func _get_cheapest_plan(plans):
	var best_plan = null
	for plan in plans:
		if best_plan == null or plan.cost < best_plan.cost:
			best_plan = plan
	return best_plan.actions


# Builds graph with actions.
# Only includes valid plans that achieve the goal.
#
# This function uses recursion to build the graph. This is
# necessary because any new action included in the graph may
# add preconditions to the desired state that can be satisfied
# by previously considered actions, meaning that on every step we
# need to iterate from the beginning to find all solutions.
#
# TODO: protect from circular dependencies.
# Returns true if the path has a solution.
func _build_plans(step, agent):
	var has_followup := false

	# Each node in the graph has its own desired state.
	var state: Dictionary = step.state.duplicate()

	# Check whether the current state is satisfied.
	for state_name in step.state:
		var actual_state = agent.get_state(state_name)
		if actual_state is Object:
			actual_state = true
		var world_state = WorldState.get_state(state_name)
		if world_state is Object:
			world_state = true
		var expected_state = state[state_name]
		if expected_state == actual_state or expected_state == world_state:
			state.erase(state_name)

	# If the state is empty, the branch already found a solution.
	if state.is_empty():
		return true

	for action in _actions:
		if not action.is_valid(agent):
			continue

		var should_use_action := false
		var effects: Dictionary = action.get_effects()
		var desired_state: Dictionary = state.duplicate()

		# Check whether the action should be used.
		for state_name in desired_state:
			if desired_state[state_name] == effects.get(state_name):
				desired_state.erase(state_name)
				should_use_action = true

		if should_use_action:
			# Add action preconditions to the desired state.
			var preconditions: Dictionary = action.get_preconditions()
			for precondition in preconditions:
				desired_state[precondition] = preconditions[precondition]

			var step_node = {
				"action": action,
				"state": desired_state,
				"children": [],
			}

			# If desired state is empty, this action can be included.
			# If it is not empty, _build_plans is called again recursively
			# so it can try to find actions that satisfy the current state.
			if desired_state.is_empty() or _build_plans(step_node, agent):
				step.children.append(step_node)
				has_followup = true

	return has_followup


# Transforms graph with actions into a list of actions and calculates cost.
func _transform_tree_into_array(p, agent):
	var plans = []

	if p.children.is_empty() and p.action.has_method("get_cost"):
		plans.append({"actions": [p.action], "cost": p.action.get_cost(agent)})
		return plans

	for child in p.children:
		for child_plan in _transform_tree_into_array(child, agent):
			if p.action.has_method("get_cost"):
				child_plan.actions.append(p.action)
				child_plan.cost += p.action.get_cost(agent)
			plans.append(child_plan)

	return plans


# Prints a plan. Used for debugging only.
func _print_plan(plan):
	var actions = []
	for action in plan.actions:
		actions.append(action.get_class_name())
	print("action_planner: ", {"cost": plan.cost, "actions": actions})

