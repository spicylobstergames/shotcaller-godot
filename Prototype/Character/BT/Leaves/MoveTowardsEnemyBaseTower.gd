extends BTLeaf

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
		
	""" ERROR move_points must have at least 2 points
	var path = GSAIPath.new(move_points)
	var ai_follow_path = GSAIFollowPath.new(agent.ai_agent, path)
	ai_follow_path.path_offset = 0.1
	ai_follow_path.prediction_time = 0.1
	ai_follow_path.arrival_tolerance = 5
	ai_follow_path.deceleration_radius = 10
	ai_follow_path.time_to_reach = 2.0
	ai_follow_path.is_arrive_enabled = false
	
	ai_follow_path.calculate_steering(agent.ai_accel)
	"""
	return NodeStatus.In_Progress
