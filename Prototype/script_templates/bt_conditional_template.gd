extends BTConditional

# A conditional node MUST NOT override _tick but only 
# _pre_tick and _post_tick.


# The condition is checked BEFORE ticking. So it should be in _pre_tick.
func _pre_tick(agent: Node, blackboard: Blackboard) -> void:
	if not blackboard.get_data("my_key"):
		verified = false
		ignore_reverse = true # This is to ignore the reverse condition flag
		return
	
	ignore_reverse = false
	
	if blackboard.get_data("my_key") == "some_value":
		verified = true
	
	blackboard.set_data("condition_verified", verified)


# (OPTIONAL) Do something after tick result is returned.
func _post_tick(agent: Node, blackboard: Blackboard, result: bool) -> void:
	blackboard.set_data("last_result", result)
