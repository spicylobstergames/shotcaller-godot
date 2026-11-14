extends Node

# Keep suite registration explicit so the headless run order is predictable.
#
# PORT NOTE: The GOAP-coupled suites from the original CI-verified suite
# (planner, agent, goal, navigation, movement, action-lifecycle tests) are
# DEFERRED until the upstream GOAP restructure settles. See COVERAGE.md
# ("Deferred coverage"). Only suites targeting stable production seams
# (skills, modifiers, spawns, collisions, map tools, parse/scene sanity)
# run here.

const CollisionTests = preload("res://tests/unit/test_collisions.gd")
const ModifiersTests = preload("res://tests/unit/test_modifiers.gd")
var PassiveSkillsTests = load("res://tests/unit/test_passive_skills.gd")
const SpawnsTests = preload("res://tests/unit/test_spawns.gd")
var MirrorTilesTests = load("res://tests/unit/test_mirror_tiles.gd")
const ScriptParseTests = preload("res://tests/unit/test_script_parse.gd")
const SceneInstantiateTests = preload("res://tests/unit/test_scene_instantiate.gd")
const HelpersTests = preload("res://tests/unit/test_helpers.gd")
const PlannerTests = preload("res://tests/unit/test_planner.gd")
const PlannerRealActionsTests = preload("res://tests/unit/test_planner_real_actions.gd")
const AgentSignalsTests = preload("res://tests/unit/test_agent_signals.gd")
const AgentTargetTests = preload("res://tests/unit/test_agent_target.gd")
const AgentTacticTests = preload("res://tests/unit/test_agent_tactic.gd")
var ActionLifecyclesTests = load("res://tests/unit/test_action_lifecycles.gd")
var GoalInteractionsTests = load("res://tests/unit/test_goal_interactions.gd")
const GoapIntegrationTests = preload("res://tests/unit/test_goap_integration.gd")
const MovementTests = preload("res://tests/unit/test_movement.gd")
const NavigationTests = preload("res://tests/unit/test_navigation.gd")
const ArriveAtDestinationTests = preload("res://tests/unit/test_arrive_at_destination.gd")
const OrderActionTests = preload("res://tests/unit/test_order_action.gd")
const AttackPrioritiesTests = preload("res://tests/unit/test_attack_priorities.gd")
const AttackLifecycleTests = preload("res://tests/unit/test_attack_lifecycle.gd")
const SightRadiusTests = preload("res://tests/unit/test_sight_radius.gd")

var tests_run := 0
var failures: Array[String] = []


func _ready() -> void:
	# Let project autoloads finish _ready before tests call into game services.
	await get_tree().process_frame
	_run_suite("Collision", CollisionTests)
	_run_suite("Modifiers", ModifiersTests)
	_run_suite("PassiveSkills", PassiveSkillsTests)
	_run_suite("Spawns", SpawnsTests)
	_run_suite("MirrorTiles", MirrorTilesTests)
	_run_suite("ScriptParse", ScriptParseTests)
	_run_suite("SceneInstantiate", SceneInstantiateTests)
	_run_suite("Helpers", HelpersTests)
	_run_suite("Planner", PlannerTests)
	_run_suite("PlannerRealActions", PlannerRealActionsTests)
	_run_suite("AgentSignals", AgentSignalsTests)
	_run_suite("AgentTarget", AgentTargetTests)
	_run_suite("AgentTactic", AgentTacticTests)
	_run_suite("ActionLifecycles", ActionLifecyclesTests)
	_run_suite("GoalInteractions", GoalInteractionsTests)
	_run_suite("GoapIntegration", GoapIntegrationTests)
	_run_suite("Movement", MovementTests)
	_run_suite("Navigation", NavigationTests)
	_run_suite("ArriveAtDestination", ArriveAtDestinationTests)
	_run_suite("OrderAction", OrderActionTests)
	_run_suite("AttackPriorities", AttackPrioritiesTests)
	_run_suite("AttackLifecycle", AttackLifecycleTests)
	_run_suite("SightRadius", SightRadiusTests)

	# Machine-checkable completion token: run_suite.sh verifies this line
	# against the pinned EXPECTED_UNIT_TESTS count in a separate file, so a
	# runner that crashes, hangs, or is bypassed cannot fake a green result.
	print("TESTS_COMPLETE: passed=%d failed=%d" % [tests_run, failures.size()])
	if failures.is_empty():
		print("All %d tests passed." % tests_run)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		push_error("%d of %d tests failed." % [failures.size(), tests_run])
		get_tree().quit(1)


# Print each suite as it starts: if a suite hangs, the CI log shows the
# exact one instead of a silent gap after "[1/3] Unit + integration suite".
func _run_suite(name: String, suite) -> void:
	print("--- running suite: ", name)
	suite.new().run(self)


func check(condition: bool, description: String) -> void:
	tests_run += 1
	if not condition:
		# Collect failures so one run reports every broken assertion.
		failures.append(description)


func check_equal(actual: Variant, expected: Variant, description: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [description, expected, actual])
