extends BTLeaf

func do_stuff(agent: Node) -> int:
	var targeted_enemy: PhysicsBody2D = agent.targeted_enemy
	
	if not is_instance_valid(targeted_enemy):
		return NodeStatus.Failure
	var skill = agent.get_node("Skills").get_skill(0)
	if skill:
		var distance_threshold = skill.get_range()
		if agent.global_position.distance_to(targeted_enemy.global_position) <= distance_threshold:
			return NodeStatus.Success
	
	var ai_pursue_chase = GSAIPursue.new(agent.ai_agent, targeted_enemy.ai_agent, 0.3)
	
	ai_pursue_chase.calculate_steering(agent.ai_accel)
	return NodeStatus.In_Progress
