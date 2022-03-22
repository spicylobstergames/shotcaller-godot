extends BTLeaf

func do_stuff(agent: Node) -> int:
	if agent.behavior_animplayer.has_animation("Idle") and agent.behavior_animplayer.current_animation != "Idle":
		agent.behavior_animplayer.play("Idle")

	return NodeStatus.Success
