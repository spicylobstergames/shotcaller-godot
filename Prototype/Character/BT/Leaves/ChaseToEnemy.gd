extends BTNode


var ai_pursue_chase: GSAIPursue

var ai_separation_chase: GSAISeparation
var ai_cohesion_chase: GSAICohesion
var ai_radius_proximity_chase: GSAIRadiusProximity
var ai_blend_chase: GSAIBlend
var ai_radius_proximity_avoid_chase: GSAIRadiusProximity
var ai_avoid_chase: GSAIAvoidCollisions
var current_pos: Vector2 = Vector2.ZERO

func do_stuff(agent: Node) -> int:
	_setup_update_closest_enemy(agent)
	_setup_ai_chase_to_enemy(agent)
	current_pos = agent.global_position
	
	var _agent: KinematicBody2D = agent
	var targeted_enemy: PhysicsBody2D = agent.targeted_enemy
	
#	_agent._setup_state_debug(name)
	
	if not is_instance_valid(targeted_enemy):
		return NodeStatus.Failure
	var distance_threshold = agent.get_node("Skills").get_skill(0).get_range() * 0.75
	if agent.global_position.distance_to(targeted_enemy.global_position) <= distance_threshold:
		return NodeStatus.Success
	
	_setup_update_ai_chase_to_enemy(targeted_enemy)
	_agent._setup_face_direction(targeted_enemy.global_position)
	ai_blend_chase.calculate_steering(_agent.ai_accel)
	_agent.ai_agent._apply_steering(_agent.ai_accel, _agent.get_physics_process_delta_time())
#	if agent.behavior_animplayer.has_animation("Walk") and agent.behavior_animplayer.current_animation != "Walk":
#		agent.behavior_animplayer.play("Walk")
	return NodeStatus.In_Progress

func _setup_ai_chase_to_enemy(agent: PhysicsBody2D) -> void:
	if not ai_pursue_chase and agent.get("targeted_enemy") is PhysicsBody2D:
		var targeted_enemy: PhysicsBody2D = agent.get("targeted_enemy")
		ai_pursue_chase = GSAIPursue.new(agent.ai_agent, targeted_enemy.ai_agent, 0.3)
		
		var ai_allies = []
		for a in agent.get("allies"):
			ai_allies.append(a.ai_agent)
			
#		var ai_enemies = []
#		for e in blackboard.get_data("enemies"):
#			if e.stats.unit_type == Units.TypeID.Building:
#				ai_allies.append(e.ai_agent)

		ai_radius_proximity_chase = GSAIRadiusProximity.new(agent.ai_agent, ai_allies, 60)
		ai_separation_chase = GSAISeparation.new(agent.ai_agent, ai_radius_proximity_chase)
		ai_cohesion_chase = GSAICohesion.new(agent.ai_agent, ai_radius_proximity_chase)
		ai_radius_proximity_avoid_chase = GSAIRadiusProximity.new(agent.ai_agent, ai_allies, agent.attributes.radius.collision_size)
		ai_avoid_chase = GSAIAvoidCollisions.new(agent.ai_agent, ai_radius_proximity_avoid_chase)

#		var aai_radius_proximity_avoid_chase = GSAIRadiusProximity.new(agent.ai_agent, ai_allies, 100)
#		var aai_avoid_chase = GSAIAvoidCollisions.new(agent.ai_agent, aai_radius_proximity_avoid_chase)

		ai_separation_chase.decay_coefficient = 100000

		ai_blend_chase = GSAIBlend.new(agent.ai_agent)
		ai_blend_chase.add(ai_cohesion_chase, 0.1)
		ai_blend_chase.add(ai_separation_chase, 10.0)
		ai_blend_chase.add(ai_pursue_chase, 3.0)
		ai_blend_chase.add(ai_avoid_chase, 2.0)
#		ai_blend_chase.add(aai_avoid_chase, 1.0)


func _setup_update_ai_chase_to_enemy(targeted_enemy: PhysicsBody2D) -> void:
	if ai_pursue_chase:
		ai_pursue_chase.target = targeted_enemy.ai_agent

func _setup_update_closest_enemy(agent: PhysicsBody2D) -> void:
		randomize()
		var enemies: Array = agent.get("enemies")
		if not enemies.empty():
			var new_targeted_enemy = agent.get("targeted_enemy")
			var distance = agent.attributes.radius.unit_detection
			for e in enemies:
				var new_distance = agent.global_position.distance_to(e.global_position)
				if new_distance < distance:
					distance = new_distance
					new_targeted_enemy = e
			
			agent.targeted_enemy = new_targeted_enemy
