extends BTNode

var ai_path: GSAIPath
var ai_follow_path: GSAIFollowPath

var move_points: Array = []


func do_stuff(agent: Node) -> int:

	if move_points.empty():
		for v in agent.get("move_points"):
			move_points.append(GSAIUtils.to_vector3(v))
	var distance_threshold = agent.get_node("Skills").get_skill(0).get_range() * 0.75
	if agent.global_position.distance_to(agent.targeted_enemy.global_position) <= distance_threshold:
		return NodeStatus.Success
	var path = GSAIPath.new(move_points)
	var ai_follow_path = GSAIFollowPath.new(agent.ai_agent, path)
	ai_follow_path.path_offset = 0.1
	ai_follow_path.prediction_time = 0.1
	ai_follow_path.arrival_tolerance = 5
	ai_follow_path.deceleration_radius = 10
	ai_follow_path.time_to_reach = 2.0
	ai_follow_path.is_arrive_enabled = false

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
	ai_blend_chase.add(ai_follow_path, 3.0)
	ai_blend_chase.add(ai_avoid_chase, 2.0)
	
	ai_blend_chase.calculate_steering(agent.ai_accel)
	return NodeStatus.In_Progress
