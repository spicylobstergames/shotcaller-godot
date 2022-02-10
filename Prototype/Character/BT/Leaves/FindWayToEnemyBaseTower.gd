extends BTNode

func do_stuff(agent: Node) -> int:

	var enemy_buildings = Units.get_enemies(
				agent,
				agent.team,
				Units.TypeID.Creep,
				[Units.TypeID.Building],
				Units.DetectionTypeID.Global,
				INF
				)
	var closest_buildings = Units.get_closest_units_by(
		agent,
		Units.SortTypeID.Distance,
		enemy_buildings
	)
	
	if closest_buildings.size() <= 0:
		return NodeStatus.Failure
	var move_points = Units.get_move_points(agent, closest_buildings[0].global_position, Units.TypeID.Creep)
	agent.targeted_enemy = closest_buildings[0]
	agent.move_points = move_points
	
	if agent.has_node("Node/Line2D"):
		var line2d: Line2D = agent.get_node("Node/Line2D")
		line2d.points = move_points
	
	agent.get_node("ObjectAvoid").enabled = true
	return NodeStatus.Success
