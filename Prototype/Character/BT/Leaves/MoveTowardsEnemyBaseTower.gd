extends BTNode

var ai_path: GSAIPath
var ai_follow_path: GSAIFollowPath

var move_points: Array = []


func do_stuff(agent: Node) -> int:

	agent.get_node("ObjectAvoid").enabled = true

	if move_points.empty():
		for v in agent.get("move_points"):
			move_points.append(GSAIUtils.to_vector3(v))
	var distance_threshold = agent.get_node("Skills").get_skill(0).get_range() * 0.75
	if is_instance_valid(agent.targeted_enemy) and agent.global_position.distance_to(agent.targeted_enemy.global_position) <= distance_threshold:
#	if agent.global_position.distance_to(agent.targeted_enemy.global_position) <= distance_threshold:
		return NodeStatus.Success
	if not move_points.empty():
		if not agent.get_node("ObjectAvoid").move_points:
			agent.get_node("ObjectAvoid").move_points = move_points
	
		agent.get_node("ObjectAvoid").custom_calculate_steering(agent.ai_agent, agent.ai_accel, 0.1)
		agent.ai_agent._apply_steering(agent.ai_accel, agent.get_physics_process_delta_time())
		return NodeStatus.In_Progress
	return NodeStatus.Success


func _setup_ai_move_to_path(agent: KinematicBody2D) -> void:
	if not ai_path and not ai_follow_path:
		ai_path = GSAIPath.new(
			[
				GSAIUtils.to_vector3(agent.global_position),
				GSAIUtils.to_vector3(agent.global_position)
			],
			true
		)
		ai_follow_path = GSAIFollowPath.new(agent.ai_agent, ai_path)
		ai_follow_path.path_offset = 0.1
		ai_follow_path.prediction_time = 0.1
		ai_follow_path.arrival_tolerance = 5
		ai_follow_path.deceleration_radius = 10
		ai_follow_path.time_to_reach = 2.0
		ai_follow_path.is_arrive_enabled = false

func _setup_update_ai_move_to_path(move_points: Array) -> void:
	ai_path.create_path(move_points)
