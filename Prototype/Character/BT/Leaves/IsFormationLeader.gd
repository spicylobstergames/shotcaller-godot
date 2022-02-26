extends BTLeaf

func do_stuff(agent: Node) -> int:
	if "leader" in agent and is_instance_valid(agent.leader):
		if agent.leader == agent:
			return NodeStatus.Success
		else:
			return NodeStatus.Failure
	return NodeStatus.Success
