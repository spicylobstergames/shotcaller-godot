extends RefCounted

# Plans with REAL production actions and REAL goal contracts.
#
# The existing test_planner.gd verifies planner mechanics with contract
# doubles; this file verifies the production CONTRACT ITSELF: that the real
# registry's actions can satisfy real goals' desired states under the real
# planner. It catches contract drift — e.g. an action renamed effect key, a
# goal desiring an unsatisfiable state, or a plan that silently becomes empty.

const Planner = preload("res://goap/goap_system/planner.gd")
const ActionRegistry = preload("res://goap/game_logic/action_registry.gd")
const GoalRegistry = preload("res://goap/game_logic/goal_registry.gd")
const WorldStateSnapshot = preload("res://tests/helpers/world_state_snapshot.gd")


# Agent double exposing exactly what real actions' is_valid() reads during
# planning: get_unit().moves / .state / .current_destiny and get_state().
class PlanAgent:
	extends RefCounted
	var unit
	var state := {}

	func _init(unit_moves: bool = true, unit_state: String = "move", has_path: bool = false):
		unit = PlanUnit.new(unit_moves, unit_state)
		state["has_path"] = has_path

	func get_unit():
		return unit

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)


# A goal whose desired state no real action can produce.
class ImpossibleGoal extends "res://goap/goap_system/goal_contract.gd":
	func get_desired_state(_agent) -> Dictionary:
		return {"no_action_produces_this": true}


class PlanUnit:
	extends RefCounted
	# Every property real actions' is_valid()/get_cost() touch during
	# planning. Defaults describe a healthy melee unit that can act.
	var moves := true
	var state := "move"
	var current_destiny := Vector2(100, 100)
	var final_destiny := Vector2(100, 100)
	var team := "blue"
	var type := "infantry"
	var dead := false
	var attacks := true
	var regen := 0
	var target = null
	var channeling_timer := 0.0
	var current_path: Array = []
	var current_step := Vector2.ZERO
	var global_position := Vector2.ZERO

	func _init(unit_moves: bool = true, unit_state: String = "move"):
		moves = unit_moves
		state = unit_state

	func set_state(_s):
		pass

	func set_navigation_target(_v):
		pass

	func get_node_or_null(_path):
		return null


func run(harness) -> void:
	var ws = WorldStateSnapshot.new()

	var planner = Planner.new()
	var registry = ActionRegistry.new()
	var actions = registry.get_all_actions()
	planner.set_actions(actions)

	# --- registry sanity: every real action honors the production contract ---
	harness.check_equal(actions.size(), 19,
		"Action registry holds all 19 production actions.")
	var contract_breaks: Array[String] = []
	for action in actions:
		if action.get_effects() == null:
			contract_breaks.append(action.get_class_name() + " (null effects)")
	harness.check(contract_breaks.is_empty(),
		"All production actions return an effects dictionary. Breaks: %s" % [", ".join(contract_breaks)])

	# --- ArriveAtDestination plans with the real MoveAction ---
	var goal_registry = GoalRegistry.new()
	var arrive_goal = goal_registry.get_goal("ArriveAtDestination")
	harness.check(arrive_goal != null, "Goal registry provides ArriveAtDestination.")
	var agent = PlanAgent.new(true, "move", false)
	var plan = planner.get_plan(agent, arrive_goal)
	harness.check(not plan.is_empty(),
		"Real planner produces a plan for the real ArriveAtDestination goal.")
	if not plan.is_empty():
		harness.check(plan[0].get_class_name() == "MoveAction",
			"ArriveAtDestination plans the real MoveAction (got %s)." % plan[0].get_class_name())
		harness.check(plan[plan.size() - 1].get_effects().has("arrived_at_destination"),
			"The plan's final action produces 'arrived_at_destination'.")

	# --- has_path=true flips planning to NavigateAction ---
	var navigating_agent = PlanAgent.new(true, "move", true)
	var nav_plan = planner.get_plan(navigating_agent, arrive_goal)
	harness.check(not nav_plan.is_empty(),
		"A navigating unit still gets an ArriveAtDestination plan.")
	if not nav_plan.is_empty():
		harness.check(nav_plan[0].get_class_name() == "NavigateAction",
			"With has_path=true the planner picks NavigateAction (got %s)." % nav_plan[0].get_class_name())

	# --- a unit that cannot move gets no plan ---
	var frozen_agent = PlanAgent.new(false, "move", false)
	harness.check(planner.get_plan(frozen_agent, arrive_goal).is_empty(),
		"A unit with moves=false gets no plan (no valid action).")

	# --- Recover chains retreat -> wait_out through real preconditions ---
	ws.set_state("is_game_active", true)
	var recover_goal = goal_registry.get_goal("Recover")
	var recover_plan = planner.get_plan(agent, recover_goal)
	harness.check(not recover_plan.is_empty(),
		"Real planner satisfies the Recover goal (retreat chain).")
	if not recover_plan.is_empty():
		var plan_names: Array = []
		for a in recover_plan:
			plan_names.append(a.get_class_name())
		harness.check(plan_names.has("RetreatAction"),
			"Recover plan includes the real RetreatAction (plan: %s)" % [", ".join(plan_names)])
		harness.check(plan_names.has("WaitOut"),
			"Recover plan includes the real WaitOut (plan: %s)" % [", ".join(plan_names)])
		# WaitOut requires arrived_at_retreat — it must come after RetreatAction.
		if plan_names.has("RetreatAction") and plan_names.has("WaitOut"):
			harness.check(plan_names.find("RetreatAction") < plan_names.find("WaitOut"),
				"WaitOut is planned after RetreatAction (its precondition).")
	ws.restore()

	# --- NeedSafety is satisfied by Hide ---
	var safety_goal = goal_registry.get_goal("NeedSafety")
	var safety_plan = planner.get_plan(agent, safety_goal)
	harness.check(not safety_plan.is_empty(),
		"Real planner satisfies the NeedSafety goal.")
	if not safety_plan.is_empty():
		harness.check(safety_plan[0].get_class_name() == "Hide",
			"NeedSafety plans the real Hide action (got %s)." % safety_plan[0].get_class_name())

	# --- a goal desiring an unsatisfiable state gets no plan ---
	harness.check(planner.get_plan(agent, ImpossibleGoal.new()).is_empty(),
		"A goal no real action can satisfy yields an empty plan.")
