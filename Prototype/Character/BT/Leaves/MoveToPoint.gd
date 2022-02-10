extends BTNode

func do_stuff(agent: Node) -> int:
	var target_point: Vector2
	target_point = agent.get("target_point")
	if agent.global_position.distance_to(target_point) < 5.0:
		return NodeStatus.Success
	
	var target = GSAIAgentLocation.new()
	target.position = GSAIUtils.to_vector3(target_point)
	
	var arrive = GSAIArrive.new(agent.ai_agent, target)
	arrive._calculate_steering(agent.ai_accel)

	return NodeStatus.In_Progress
