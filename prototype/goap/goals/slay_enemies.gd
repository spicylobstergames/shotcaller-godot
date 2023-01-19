extends "../Goal.gd"

class_name SlayEnemiesGoal

func get_class(): return "SlayEnemiesGoal"

#initially checks for enemies being around and being an attacking unit. If it becomes true, its sets the agent state and refers to it going forward
func is_valid(agent) -> bool:
	var enemy_near = agent.get_state("target_enemy_active") or agent.get_unit().attacks and agent.get_unit().get_units_on_sight({"team": agent.get_unit().opponent_team()}).size() > 0
	if enemy_near:
		agent.set_state("target_enemy_active", true)
		return true
	return false


func priority(agent) -> int:
	return 40


func get_desired_state(agent) -> Dictionary:
	return {
		"target_enemy_active": false
	}
