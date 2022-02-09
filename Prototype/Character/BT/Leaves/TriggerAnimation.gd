extends BTNode
export var animation: String
func do_stuff(agent: Node) -> int:
	if agent.behavior_animplayer.has_animation(animation) and agent.behavior_animplayer.current_animation != animation:
		agent.behavior_animplayer.play(animation)
	return NodeStatus.Success
