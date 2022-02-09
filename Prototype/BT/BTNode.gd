class_name BTNode extends Node

enum NodeStatus{
	Success,
	Failure,
	In_Progress,
	Error
}

enum NodeType{
	Leaf,
	Sequential,
	Selector
}

export(NodeType) var node_type: int

func tick(agent: Node) -> int:
	match node_type:
		NodeType.Leaf:
			if agent.has_method("_setup_state_debug"):
				agent._setup_state_debug(name)
			return do_stuff(agent)
		NodeType.Sequential:
			for child in get_children():
				var child_status = child.tick(agent)
				if child_status == NodeStatus.In_Progress:
					return NodeStatus.In_Progress
				elif child_status == NodeStatus.Failure:
					return NodeStatus.Failure
			return NodeStatus.Success
		NodeType.Selector:
			for child in get_children():
				var child_status = child.tick(agent)
				if child_status == NodeStatus.In_Progress:
					return NodeStatus.In_Progress
				elif child_status == NodeStatus.Success:
					return NodeStatus.Success
			return NodeStatus.Failure
		_:
			push_error("Invalid node type")
			return NodeStatus.Error

func do_stuff(agent: Node) -> int:
	return NodeStatus.Success
