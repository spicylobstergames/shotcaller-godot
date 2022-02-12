extends BTLeaf

func do_stuff(agent: Node) -> int:
	var targeted_enemy: PhysicsBody2D = agent.targeted_enemy
	
	if not is_instance_valid(targeted_enemy):
		return NodeStatus.Failure
	var distance_threshold = agent.get_node("Skills").get_skill(0).get_range() * 0.75
	if agent.global_position.distance_to(targeted_enemy.global_position) <= distance_threshold:
		return NodeStatus.Success
	
	var ai_pursue_chase = GSAIPursue.new(agent.ai_agent, targeted_enemy.ai_agent, 0.3)
	
	var ai_allies = []
	for ally in agent.allies:
		ai_allies.append(ally.ai_agent)

	var ai_radius_proximity_chase = GSAIRadiusProximity.new(agent.ai_agent, ai_allies, 60)
	var ai_separation_chase = GSAISeparation.new(agent.ai_agent, ai_radius_proximity_chase)
	var ai_cohesion_chase = GSAICohesion.new(agent.ai_agent, ai_radius_proximity_chase)
	var ai_radius_proximity_avoid_chase = GSAIRadiusProximity.new(agent.ai_agent, ai_allies, agent.attributes.radius.collision_size)
	var ai_avoid_chase = GSAIAvoidCollisions.new(agent.ai_agent, ai_radius_proximity_avoid_chase)

	ai_separation_chase.decay_coefficient = 100000

	var ai_blend_chase = GSAIBlend.new(agent.ai_agent)
	ai_blend_chase.add(ai_cohesion_chase, 0.1)
	ai_blend_chase.add(ai_separation_chase, 10.0)
	ai_blend_chase.add(ai_pursue_chase, 3.0)
	ai_blend_chase.add(ai_avoid_chase, 2.0)
	
	ai_blend_chase.calculate_steering(agent.ai_accel)
	return NodeStatus.In_Progress
