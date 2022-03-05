extends BTLeaf

func do_stuff(agent: Node) -> int:
	var lane_points = PoolVector2Array([]) + agent.lane.points
	if agent.attributes.primary.unit_team == Units.TeamID.Red:
		lane_points.invert()
	if agent.current_lane_point >= lane_points.size():
		return NodeStatus.Failure
	while agent.global_position.distance_to(lane_points[agent.current_lane_point]) < 10.0:
		agent.current_lane_point += 1
		if agent.current_lane_point >= lane_points.size():
			return NodeStatus.Failure

	var move_points = Units.get_move_points(agent, lane_points[agent.current_lane_point], Units.TypeID.Creep)
	agent.move_points = move_points

	if ProjectSettings.get("global/debug") and agent.has_node("Node/Line2D"):
		var line2d: Line2D = agent.get_node("Node/Line2D")
		line2d.points = move_points
	
	return NodeStatus.Success
