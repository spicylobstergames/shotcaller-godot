extends "res://goap/goap_system/goal_contract.gd"

# Canonical mock goal for GOAP tests. Extends the real GoalContract so
# production code paths (is_valid/priority dispatch) are exercised.
#
# Tracks call counts so tests can assert HOW production queries goals
# (e.g. that is_valid is consulted before priority). Tests extend this
# for extra behavior (plan arrays, side effects) rather than redefining it.


var valid: bool = true
var prio: int = 1
var valid_calls: int = 0
var priority_calls: int = 0
var on_valid: Callable = Callable()


func _init(v: bool = true, p: int = 1) -> void:
	valid = v
	prio = p


func is_valid(_agent: Variant) -> bool:
	valid_calls += 1
	if not on_valid.is_null():
		on_valid.call()
	if not valid:
		return false
	return true


func priority(_agent: Variant) -> int:
	priority_calls += 1
	return prio


# The real goals each define get_class_name(); the agent reads it during
# _replace_plan (state_changed emission) and _get_best_goal consumers may
# too. The contract base class does not provide it.
func get_class_name() -> String:
	return "MockGoal"
