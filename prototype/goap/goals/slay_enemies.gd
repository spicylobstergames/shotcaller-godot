extends GoapGoal

class_name SlayEnemiesGoal

func get_class(): return "SlayEnemiesGoal"

func is_valid(agent) -> bool:
    var enemy_near = agent.get_state("enemy_active") or agent.unit.attacks and agent.unit.get_units_on_sight({"team": agent.unit.oponent_team()}).size() > 0
    if enemy_near:
        agent.set_state("enemy_active", true)
        return true
    return false


func priority(agent) -> int:
	return 40


func get_desired_state(agent) -> Dictionary:
	return {
		"enemy_active": false
	}
