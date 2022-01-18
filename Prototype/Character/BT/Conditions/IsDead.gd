extends BTConditional


func _pre_tick(agent: Node, blackboard: Blackboard) -> void:
	verified = blackboard.get_data("is_dead")
