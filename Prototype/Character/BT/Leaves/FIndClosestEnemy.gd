extends BTNode

func do_stuff(agent: Node) -> int:
	
	var sorted_enemies = Units.get_closest_units_by(agent, Units.SortTypeID.Distance, agent.enemies)
	if sorted_enemies.size() <= 0:
		return NodeStatus.Failure
	var closest_enemy = Units.get_closest_units_by(agent, Units.SortTypeID.Distance, agent.enemies)[0]
	
	agent.targeted_enemy = closest_enemy
	return NodeStatus.Success
