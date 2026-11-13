extends RefCounted

# Plans with REAL production actions and REAL goal contracts.
#
# The existing test_planner.gd verifies planner mechanics with contract
# doubles; this file verifies the production CONTRACT ITSELF: that the real
# registry's actions can satisfy real goals' desired states under the real
# planner. It catches contract drift — e.g. an action renamed effect key, a
# goal desiring an unsatisfiable state, or a plan that silently becomes empty.
#
# PORT (post-restructure): class names are now "Move"/"Navigate"/"Retreat"/
# "WaitForRegeneration"; wait_out was deleted and the Recover chain is now
# Retreat -> WaitForRegeneration (via arrived_at_retreat); Move's precondition
# is has_destiny (produced by Navigate), not has_path.

const Planner = preload("res://goap/goap_system/planner.gd")
const ActionRegistry = preload("res://goap/game_logic/action_registry.gd")
const GoalRegistry = preload("res://goap/game_logic/goal_registry.gd")
const WorldStateSnapshot = preload("res://tests/helpers/world_state_snapshot.gd")


# Agent double exposing exactly what real actions' is_valid() reads during
# planning: get_unit() and get_state(). The initial state mirrors the real
# agent's reset() defaults — in particular is_stunned=false, because the
# planner does NOT treat an unset key as false (null != false).
class PlanAgent:
	extends RefCounted
	var unit
	var state := {}

	func _init(unit_moves: bool = true):
		unit = PlanUnit.new(unit_moves)
		state["is_stunned"] = false

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
	var regen := 1  # healthy leader: WaitForRegeneration requires regen > 0
	var state := "move"
	var current_destiny := Vector2(100, 100)
	var final_destiny := Vector2(100, 100)
	var team := "blue"
	var type := "infantry"
	var dead := false
	var attacks := true
	var target = null
	var channeling_timer := 0.0
	var current_path: Array = []
	var current_step := Vector2.ZERO
	var global_position := Vector2.ZERO

	func _init(unit_moves: bool = true):
		moves = unit_moves

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

	# --- ArriveAtDestination plans Navigate -> Move through real preconditions ---
	var goal_registry = GoalRegistry.new()
	var arrive_goal = goal_registry.get_goal("ArriveAtDestination")
	harness.check(arrive_goal != null, "Goal registry provides ArriveAtDestination.")
	var agent = PlanAgent.new(true)
	var plan = planner.get_plan(agent, arrive_goal)
	harness.check(not plan.is_empty(),
		"Real planner produces a plan for the real ArriveAtDestination goal.")
	if not plan.is_empty():
		harness.check(plan[0].get_class_name() == "Navigate",
			"ArriveAtDestination plans the real Navigate first (got %s)." % plan[0].get_class_name())
		harness.check(plan[plan.size() - 1].get_class_name() == "Move",
			"ArriveAtDestination plans the real Move last (got %s)." % plan[plan.size() - 1].get_class_name())
		harness.check(plan[plan.size() - 1].get_effects().has("arrived_at_destination"),
			"The plan's final action produces 'arrived_at_destination'.")
		# Move requires has_destiny; Navigate produces it — order is contractual.
		harness.check(plan.find(plan[plan.size() - 1]) > plan.find(plan[0]),
			"Move is planned after Navigate (its has_destiny precondition).")

	# --- a unit that cannot move gets no plan ---
	var frozen_agent = PlanAgent.new(false)
	harness.check(planner.get_plan(frozen_agent, arrive_goal).is_empty(),
		"A unit with moves=false gets no plan (no valid action).")

	# --- Recover chains retreat -> wait_for_regeneration through real preconditions ---
	ws.set_state("is_game_active", true)
	var recover_goal = goal_registry.get_goal("Recover")
	harness.check(recover_goal != null, "Goal registry provides Recover.")
	var recover_plan = planner.get_plan(agent, recover_goal)
	harness.check(not recover_plan.is_empty(),
		"Real planner satisfies the Recover goal (retreat chain).")
	if not recover_plan.is_empty():
		var plan_names: Array = []
		for a in recover_plan:
			plan_names.append(a.get_class_name())
		harness.check(plan_names.has("Retreat"),
			"Recover plan includes the real Retreat (plan: %s)" % [", ".join(plan_names)])
		harness.check(plan_names.has("WaitForRegeneration"),
			"Recover plan includes the real WaitForRegeneration (plan: %s)" % [", ".join(plan_names)])
		# WaitForRegeneration requires arrived_at_retreat — it must come after Retreat.
		if plan_names.has("Retreat") and plan_names.has("WaitForRegeneration"):
			harness.check(plan_names.find("Retreat") < plan_names.find("WaitForRegeneration"),
				"WaitForRegeneration is planned after Retreat (its precondition).")
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
