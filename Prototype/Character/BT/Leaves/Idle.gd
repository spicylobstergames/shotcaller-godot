extends BTLeaf



func _tick(agent: Node, blackboard: Blackboard) -> bool:
	if agent.behavior_animplayer.has_animation("Idle") and agent.behavior_animplayer.current_animation != "Idle":
		agent.behavior_animplayer.play("Idle")

	if not blackboard.get_data("enemies").empty():
		return fail()
	
	if not blackboard.get_data("buildings").empty():
		return fail()

		
	return succeed()
