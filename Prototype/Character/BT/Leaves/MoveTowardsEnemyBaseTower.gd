extends BTLeaf

var ai_path: GSAIPath
var ai_follow_path: GSAIFollowPath

var move_points: Array = []


func do_stuff(agent: Node) -> int:
	
	move_points = []
	for v in agent.get("move_points"):
		move_points.append(GSAIUtils.to_vector3(v))
	var path = GSAIPath.new(move_points)
	var ai_follow_path = GSAIFollowPath.new(agent.ai_agent, path)
	ai_follow_path.path_offset = 0.1
	ai_follow_path.prediction_time = 0.1
	ai_follow_path.arrival_tolerance = 5
	ai_follow_path.deceleration_radius = 10
	ai_follow_path.time_to_reach = 2.0
	ai_follow_path.is_arrive_enabled = false
	
	ai_follow_path.calculate_steering(agent.ai_accel)
	return NodeStatus.In_Progress
