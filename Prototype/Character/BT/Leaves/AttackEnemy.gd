extends BTLeaf


func _tick(agent: Node, blackboard: Blackboard) -> bool:
	var _agent: KinematicBody2D = agent
	var targeted_enemy: PhysicsBody2D = blackboard.get_data("targeted_enemy")
	
	if targeted_enemy == null:
		blackboard.set_data("targeted_enemy", null)
		return fail()

	if blackboard.get_data("enemies").empty():
		return fail()
#
	if blackboard.get_data("is_dead") or targeted_enemy.is_dead:
		if targeted_enemy.stats.unit_type == Units.TypeID.Building:
			var buildings: Array = blackboard.get_data("buildings")
			buildings.erase(targeted_enemy)
		blackboard.set_data("targeted_enemy", null)
		return fail()
#
#	if _agent.global_position.distance_to(targeted_enemy.global_position) >= (_agent.stats.area_attack_range + targeted_enemy.stats.area_unit/2):
#		blackboard.set_data("targeted_enemy", null)
#		return succeed()
	
	_agent._setup_state_debug("{0}: {1}".format([name, targeted_enemy.name]))
	
	match targeted_enemy.stats.unit_type:
		Units.TypeID.Creep:
			_agent.stats.state_action = Units.ActionStateID.AttackCreep
		Units.TypeID.Leader:
			_agent.stats.state_action = Units.ActionStateID.AttackLeader
		Units.TypeID.Building:
			_agent.stats.state_action = Units.ActionStateID.AttackBuilding
	
	if agent.behavior_animplayer.has_animation("Attack") and agent.behavior_animplayer.current_animation != "Attack":
		agent.behavior_animplayer.play("Attack")
	
	return succeed()
