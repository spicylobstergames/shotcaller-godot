class_name BTSelector, "res://BT/Icons/selector.png" extends BTNode

func tick(agent: Node) -> int:
	for child in get_children():
		var child_status = child.tick(agent)
		if child_status == NodeStatus.In_Progress:
			return NodeStatus.In_Progress
		elif child_status == NodeStatus.Success:
			return NodeStatus.Success
	return NodeStatus.Failure
