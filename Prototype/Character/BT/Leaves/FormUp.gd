extends BTLeaf

func do_stuff(agent: Node) -> int:
	var target_point: Vector2
	if not is_instance_valid(agent.leader):
		return NodeStatus.Failure
	target_point = agent.leader.to_global(agent.formation_target)
	if agent.global_position.distance_to(target_point) < 10.0:
		return NodeStatus.Success
	
	var move_points = Units.get_move_points(agent, target_point, Units.TypeID.Creep)
	if move_points[0].distance_to(move_points[1]) <= 1.0:
		return NodeStatus.Failure
	var path_points = []
	for point in move_points:
		path_points.append(GSAIUtils.to_vector3(point))
	
	
	var path = GSAIPath.new(path_points)
	
	var ai_follow_path = GSAIFollowPath.new(agent.ai_agent, path)
	ai_follow_path.path_offset = 0.1
	ai_follow_path.prediction_time = 0.1
	ai_follow_path.arrival_tolerance = 5
	ai_follow_path.deceleration_radius = 10
	ai_follow_path.time_to_reach = 2.0
	ai_follow_path.is_arrive_enabled = false
	
	ai_follow_path.calculate_steering(agent.ai_accel)
	
	return NodeStatus.In_Progress
