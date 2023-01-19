extends "../Goal.gd"

class_name RetreatGoal

func get_class(): return "RetreatGoal"

#initially checks for enemies being around and being an attacking unit. If it becomes true, its sets the agent state and refers to it going forward
func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	if(agent.get_state("is_retreating") || agent.get_state("command_retreat")):
		return true
	if Behavior.orders.should_retreat(unit):
		agent.set_state("is_retreating", true)
		agent.set_state("arrived_at_retreat", false)
		return true
	return false


#after it reaches the retreat point, it will bit able to switch goals up to 10 tiles away, then the priority goes back to full
func priority(agent) -> int:
	if(agent.get_state("arrived_at_retreat") and agent.get_state("retreat_pos") and agent.get_unit().point_collision(agent.get_state("retreat_pos"), agent.get_unit().game.map.tile_size*2)): 
		return 15
	elif agent.get_state("command_retreat"):
		return 1000
	else:
		return 100


func get_desired_state(agent) -> Dictionary:
	return {
		"is_retreating": false
	}
