class_name BTSequentialRandom, "res://BT/Icons/random_sequential.png" extends BTSequential

func tick(agent:Node) -> int:
	
	var shuffled_children = get_children()
	shuffled_children.shuffle()
	for child in shuffled_children:
		var child_status = child.tick(agent)
		if child_status == NodeStatus.In_Progress:
			return NodeStatus.In_Progress
		elif child_status == NodeStatus.Failure:
			return NodeStatus.Failure
	return NodeStatus.Success
