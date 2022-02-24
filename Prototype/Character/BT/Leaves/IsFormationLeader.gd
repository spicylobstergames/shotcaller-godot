extends BTLeaf

export var flipped = false

func do_stuff(agent: Node) -> int:
	if "leader" in agent and is_instance_valid(agent.leader):
		if agent.leader == agent:
			if flipped:
				return NodeStatus.Failure
			return NodeStatus.Success
		else:
			if flipped:
				return NodeStatus.Success
			return NodeStatus.Failure
	return NodeStatus.Success
