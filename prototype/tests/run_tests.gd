extends Node

# Keep suite registration explicit so the headless run order is predictable.
const ArriveAtDestinationTests = preload("res://tests/unit/test_arrive_at_destination.gd")
const AttackPrioritiesTests = preload("res://tests/unit/test_attack_priorities.gd")
const AgentSignalsTests = preload("res://tests/unit/test_agent_signals.gd")
const AgentTargetTests = preload("res://tests/unit/test_agent_target.gd")
const AgentTacticTests = preload("res://tests/unit/test_agent_tactic.gd")
const CollisionTests = preload("res://tests/unit/test_collisions.gd")
const MovementTests = preload("res://tests/unit/test_movement.gd")
const NavigationTests = preload("res://tests/unit/test_navigation.gd")
const OrderActionTests = preload("res://tests/unit/test_order_action.gd")
const OrdersPanelSignalTests = preload("res://tests/unit/test_orders_panel_signal.gd")
const PlannerTests = preload("res://tests/unit/test_planner.gd")
const ModifiersTests = preload("res://tests/unit/test_modifiers.gd")
const PassiveSkillsTests = preload("res://tests/unit/test_passive_skills.gd")
const SpawnsTests = preload("res://tests/unit/test_spawns.gd")
const GoalInteractionsTests = preload("res://tests/unit/test_goal_interactions.gd")
const MirrorTilesTests = preload("res://tests/unit/test_mirror_tiles.gd")
const ActionLifecyclesTests = preload("res://tests/unit/test_action_lifecycles.gd")

var tests_run := 0
var failures: Array[String] = []


func _ready() -> void:
	# Let project autoloads finish _ready before tests call into game services.
	await get_tree().process_frame
	ArriveAtDestinationTests.new().run(self)
	AttackPrioritiesTests.new().run(self)
	AgentSignalsTests.new().run(self)
	AgentTargetTests.new().run(self)
	AgentTacticTests.new().run(self)
	CollisionTests.new().run(self)
	MovementTests.new().run(self)
	NavigationTests.new().run(self)
	OrderActionTests.new().run(self)
	OrdersPanelSignalTests.new().run(self)
	PlannerTests.new().run(self)
	ModifiersTests.new().run(self)
	PassiveSkillsTests.new().run(self)
	SpawnsTests.new().run(self)
	GoalInteractionsTests.new().run(self)
	MirrorTilesTests.new().run(self)
	ActionLifecyclesTests.new().run(self)

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
