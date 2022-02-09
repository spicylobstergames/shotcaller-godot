extends BTNode

func do_stuff(agent: Node) -> int:
	var target_point: Vector2
	target_point = agent.get("target_point")
	if agent.global_position.distance_to(target_point) < 1.0:
		return NodeStatus.Success
	
	var target = GSAIAgentLocation.new()
	target.position = GSAIUtils.to_vector3(target_point)
	
	var seek = GSAISeek.new(agent.ai_agent, target)
	seek._calculate_steering(agent.ai_accel)
	
	agent.ai_agent._apply_steering(agent.ai_accel, agent.get_physics_process_delta_time())

	if agent.behavior_animplayer.has_animation("Walk") and agent.behavior_animplayer.current_animation != "Walk":
		agent.behavior_animplayer.play("Walk")
	
	return NodeStatus.In_Progress
