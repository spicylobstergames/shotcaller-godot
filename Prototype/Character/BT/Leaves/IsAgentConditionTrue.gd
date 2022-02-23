extends BTLeaf

export var key: String

func do_stuff(agent: Node) -> int:
	if key in agent and agent.get(key):
		return NodeStatus.Success
	else:
		return NodeStatus.Failure
