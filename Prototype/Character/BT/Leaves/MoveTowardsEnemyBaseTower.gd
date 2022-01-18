extends BTLeaf

var ai_path: GSAIPath
var ai_follow_path: GSAIFollowPath

var move_points: Array = []


func _pre_tick(agent: Node, blackboard: Blackboard) -> void:
	var _agent:KinematicBody2D = agent

#	_setup_ai_move_to_path(_agent, blackboard)
	_agent.get_node("ObjectAvoid").enabled = true
	
	if not blackboard.has_data("move_points") or not blackboard.has_data("target_end_point"):
		 fail()

	if move_points.empty():
		for v in blackboard.get_data("move_points"):
			move_points.append(GSAIUtils.to_vector3(v))

#		if move_points.size() > 1:
#			_setup_update_ai_move_to_path(move_points)

	if _agent.behavior_animplayer.has_animation("Walk") and _agent.behavior_animplayer.current_animation != "Walk":
		_agent.behavior_animplayer.play("Walk")


func _tick(agent: Node, blackboard: Blackboard) -> bool:
	var _agent:KinematicBody2D = agent
	
	_agent._setup_state_debug(name)
	Units.get_move_points(_agent, blackboard.get_data("target_end_point"), Units.TypeID.Creep)

	if blackboard.get_data("stats_health") <= 0:
		return fail()
		
	if _agent.global_position.distance_to(blackboard.get_data("target_end_point")) < _agent.stats.area_attack_range:
		_agent.get_node("ObjectAvoid").enabled = false
		return fail()

	if blackboard.has_data("enemies") and blackboard.get_data("enemies"):
		_agent.get_node("ObjectAvoid").enabled = false
		return fail()

	if not move_points.empty():
		if not _agent.get_node("ObjectAvoid").move_points:
			_agent.get_node("ObjectAvoid").move_points = move_points
	
		_agent.get_node("ObjectAvoid").custom_calculate_steering(_agent.ai_agent, _agent.ai_accel, 0.1)
		_agent.ai_agent._apply_steering(_agent.ai_accel, _agent.get_physics_process_delta_time())
		
	return succeed()


func _setup_ai_move_to_path(agent: KinematicBody2D, blackboard: Blackboard) -> void:
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
