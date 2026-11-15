extends RefCounted

# Contract lint: the GOAP registries must stay self-consistent, every script
# must carry its GOAP-GUIDE banner, and every goal's desired fact must have
# some producer.
#
# The registry counters in test_planner_real_actions.gd catch COUNT drift;
# this file catches CONTRACT drift (duplicate/missing class names, an action
# with no effects that nobody meant to be a service object, a goal desiring a
# fact no action produces).

const ActionRegistry = preload("res://goap/game_logic/action_registry.gd")
const GoalRegistry = preload("res://goap/game_logic/goal_registry.gd")
const FsScan = preload("res://tests/helpers/fs_scan.gd")
const GoapScan = preload("res://tests/helpers/goap_scan.gd")

const GOAL_NAMES := [
	"ArriveAtDestination",
	"EnemyDefeated",
	"FriendsSafe",
	"NeedLumber",
	"NeedSafety",
	"ObeyPlayer",
	"Recover",
	"WalkLane",
]

# Actions that deliberately have no effects and are therefore never selected by
# the planner. Adding a new no-effect action must fail this test on purpose:
# either give it effects or add it here and document it as a service object.
const SERVICE_ACTIONS := [
	"ChooseTactics",
	"Conquer",
	"MeleeAttack",
	"Mine",
	"Pray",
	"RangeAttack",
	"Taxes",
]


class StubAgent:
	extends RefCounted

	func get_state(_name, default = null):
		return default

	func get_unit():
		return null


func run(harness) -> void:
	# --- every GOAP script carries its guide banner ---
	var files: Array[String] = []
	FsScan.collect("res://goap", ".gd", files)
	var missing: Array[String] = []
	for path in files:
		if not FileAccess.get_file_as_string(path).contains("GOAP-GUIDE"):
			missing.append(path)
	harness.check(
		files.size() >= 35, "Banner scan covered the GOAP tree (%d scripts)." % files.size()
	)
	harness.check(
		missing.is_empty(),
		"Every GOAP script carries a GOAP-GUIDE banner. Missing: %s" % [", ".join(missing)]
	)

	# --- registry contract integrity ---
	var actions = ActionRegistry.new()
	var goals = GoalRegistry.new()
	var action_problems: Array[String] = actions.validate()
	var goal_problems: Array[String] = goals.validate()
	harness.check(
		action_problems.is_empty(),
		"Action registry contract is clean. Problems: %s" % [", ".join(action_problems)]
	)
	harness.check(
		goal_problems.is_empty(),
		"Goal registry contract is clean. Problems: %s" % [", ".join(goal_problems)]
	)

	# --- class names resolve, and no-effect actions are the known services ---
	var unresolved: Array[String] = []
	var empty_effects: Array[String] = []
	for action in actions.get_all_actions():
		var action_name: String = action.get_class_name()
		if actions.get_action(action_name) != action:
			unresolved.append(action_name)
		if action.get_effects().is_empty():
			empty_effects.append(action_name)
	harness.check(
		unresolved.is_empty(),
		"Every action class name resolves through get_action(). Unresolved: %s" % [", ".join(unresolved)]
	)
	empty_effects.sort()
	var expected_services := SERVICE_ACTIONS.duplicate()
	expected_services.sort()
	harness.check_equal(
		empty_effects,
		expected_services,
		"Actions with no effects are exactly the known service actions (add a new one here deliberately)."
	)

	# --- every goal desired fact has a producer ---
	var scan = GoapScan.new()
	scan.scan()
	var producers := {}
	for action in actions.get_all_actions():
		for key in action.get_effects():
			producers[key] = true
	for key in scan.state_calls:
		producers[key] = true

	var stub = StubAgent.new()
	var unsatisfiable: Array[String] = []
	var empty_desired: Array[String] = []
	for goal_name in GOAL_NAMES:
		var goal = goals.get_goal(goal_name)
		if goal == null:
			unsatisfiable.append("%s (not registered)" % goal_name)
			continue
		var desired: Dictionary = goal.get_desired_state(stub)
		if desired.is_empty():
			empty_desired.append(goal_name)
		for key in desired:
			if not producers.has(key):
				unsatisfiable.append("%s desires '%s' with no producer" % [goal_name, key])
	harness.check(
		unsatisfiable.is_empty(),
		"Every goal desired fact has a producer. Unsatisfiable: %s" % [", ".join(unsatisfiable)]
	)
	harness.check(
		empty_desired.is_empty(),
		"No registered goal has an empty desired state. Empty: %s" % [", ".join(empty_desired)]
	)
