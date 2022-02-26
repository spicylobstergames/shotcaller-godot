extends BTLeaf

func do_stuff(agent: Node) -> int:
	
	var sorted_enemies = Units.get_closest_units_by(agent, Units.SortTypeID.Distance, agent.enemies)
	if sorted_enemies.size() <= 0:
		return NodeStatus.Failure
	var closest_enemy = sorted_enemies[0]
	
#	var distance_threshold = agent.get_node("Skills").get_skill(0).get_range() * 0.75
#	if agent.global_position.distance_to(closest_enemy.global_position) > distance_threshold:
#		return NodeStatus.Failure
	
	agent.targeted_enemy = closest_enemy
	return NodeStatus.Success
