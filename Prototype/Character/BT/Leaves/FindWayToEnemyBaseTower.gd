extends BTLeaf

func _tick(agent: Node, blackboard: Blackboard) -> bool:
	var _agent: KinematicBody2D = agent
	
	_agent._setup_state_debug(name)

	if blackboard.get_data("stats_health") <= 0:
		return fail()

	if not blackboard.has_data("target_end_point"):
		return fail()
		
	var target_end_point = blackboard.get_data("target_end_point")
	var move_points = Units.get_move_points(_agent, target_end_point, Units.TypeID.Creep)

	blackboard.set_data("move_points", move_points)
	
	if _agent.has_node("Node/Line2D"):
		var line2d: Line2D = _agent.get_node("Node/Line2D")
		line2d.points = move_points
	
	_agent.get_node("ObjectAvoid").enabled = true
	return succeed()
