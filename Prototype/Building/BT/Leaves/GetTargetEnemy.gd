extends BTLeaf


func _tick(agent: Node, blackboard: Blackboard) -> bool:
	var _agent: KinematicBody2D = agent
	var targeted_enemy: PhysicsBody2D = blackboard.get_data("targeted_enemy")
	
	_setup_update_closest_enemy(_agent, blackboard)
	
	if targeted_enemy != null:
		return succeed()

		
	return fail()


func _setup_update_closest_enemy(agent: PhysicsBody2D, blackboard: Blackboard) -> void:
		randomize()
		var enemies: Array = blackboard.get_data("enemies")
		if not enemies.empty():
			var new_targeted_enemy = blackboard.get_data("targeted_enemy")
			var distance = agent.stats.area_unit_detection
			for e in enemies:
				var new_distance = agent.global_position.distance_to(e.global_position)
				if new_distance < distance:
					distance = new_distance
					new_targeted_enemy = e
			
			blackboard.set_data("targeted_enemy", new_targeted_enemy)
