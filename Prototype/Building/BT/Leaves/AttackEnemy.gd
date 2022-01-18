extends BTLeaf


func _tick(agent: Node, blackboard: Blackboard) -> bool:
	var _agent: KinematicBody2D = agent
	var targeted_enemy: PhysicsBody2D = blackboard.get_data("targeted_enemy")
	
	if agent.behavior_animplayer.has_animation("Attack") and agent.behavior_animplayer.current_animation != "Attack":
		agent.behavior_animplayer.play("Attack")
	
	if blackboard.get_data("stats_health") <= 0:
		blackboard.set_data("targeted_enemy", null)
		return fail()

	if _agent.global_position.distance_to(targeted_enemy.global_position) >= (_agent.stats.area_attack_range + targeted_enemy.stats.area_unit):
		blackboard.set_data("targeted_enemy", null)
		return fail()

	return succeed()
