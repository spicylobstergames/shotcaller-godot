class_name BTSelectorRandom, "res://BT/Icons/random_selector.png" extends BTSelector

func tick(agent: Node) -> int:
	var shuffled_children = get_children()
	shuffled_children.shuffle()
	for child in shuffled_children:
		var child_status = child.tick(agent)
		if child_status == NodeStatus.In_Progress:
			return NodeStatus.In_Progress
		elif child_status == NodeStatus.Success:
			return NodeStatus.Success
	return NodeStatus.Failure
