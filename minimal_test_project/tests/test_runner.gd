extends Node

const ActionLifecyclesTests = preload("res://tests/unit/test_action_lifecycles.gd")

var tests_run := 0
var failures: Array[String] = []


func _ready() -> void:
	# Let autoloads finish _ready before tests run
	await get_tree().process_frame
	ActionLifecyclesTests.new().run(self)

	if failures.is_empty():
		print("All %d tests passed." % tests_run)
		get_tree().quit(0)
	else:
		for f in failures:
			push_error(f)
		push_error("%d of %d tests failed." % [failures.size(), tests_run])
		get_tree().quit(1)


func check(condition: bool, description: String) -> void:
	tests_run += 1
	if not condition:
		failures.append(description)


func check_equal(actual: Variant, expected: Variant, description: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [description, expected, actual])
