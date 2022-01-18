extends BTConditional

func _pre_tick(agent: Node, blackboard: Blackboard) -> void:
	if blackboard.has_data("enemies"):
		verified = not blackboard.get_data("enemies").empty()

