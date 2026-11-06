extends Node

const GoalInteractionsTests = preload("res://tests/unit/test_goal_interactions.gd")

var tests_run := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	tests_run += 1
	if not condition:
		failures.append(description)

func check_equal(actual: Variant, expected: Variant, description: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [description, expected, actual])

func _ready() -> void:
	GoalInteractionsTests.new().run(self)

	if failures.is_empty():
		print("All %d tests passed." % tests_run)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		push_error("%d of %d tests failed." % [failures.size(), tests_run])
		get_tree().quit(1)
