class_name BTLeaf, "res://BT/Icons/leaf.png" extends BTNode

func tick(agent: Node) -> int:
	if agent.has_method("_setup_state_debug"):
		agent._setup_state_debug(name)
	return do_stuff(agent)

