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

var tests_run := 0
var failures: Array[String] = []


func _ready() -> void:
	# Let project autoloads finish _ready before tests call into game services.
	await get_tree().process_frame
	CollisionTests.new().run(self)
	ModifiersTests.new().run(self)
	PassiveSkillsTests.new().run(self)
	SpawnsTests.new().run(self)
	MirrorTilesTests.new().run(self)
	ScriptParseTests.new().run(self)
	SceneInstantiateTests.new().run(self)
	HelpersTests.new().run(self)
	PlannerTests.new().run(self)
	PlannerRealActionsTests.new().run(self)
	AgentSignalsTests.new().run(self)
	AgentTargetTests.new().run(self)
	AgentTacticTests.new().run(self)

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


func check(condition: bool, description: String) -> void:
	tests_run += 1
	if not condition:
		# Collect failures so one run reports every broken assertion.
		failures.append(description)


func check_equal(actual: Variant, expected: Variant, description: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [description, expected, actual])
