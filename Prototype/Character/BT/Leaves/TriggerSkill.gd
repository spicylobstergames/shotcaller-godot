extends BTNode

export var ability_index: int

func do_stuff(agent: Node) -> int:
#	if agent.get_node("Skills").trigger_skill(ability_index):
#		return NodeStatus.Success
#	else:
#		return NodeStatus.Failure
	agent.get_node("Skills").trigger_skill(ability_index)
	return NodeStatus.Success

