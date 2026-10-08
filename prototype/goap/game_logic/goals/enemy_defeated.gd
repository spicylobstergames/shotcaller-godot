extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "EnemyDefeated"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	if not unit.attacks:
		Goap.attack.set_target(unit, null)
		agent.set_state("enemy_dead", false)
		agent.set_state("enemy_in_attack_range", false)
		return false
	var target = unit.target
	var enemies_in_range = unit.get_units_in_attack_range({"team": unit.opponent_team()})
	var target_in_range = Goap.attack.select_target(unit, enemies_in_range)
	if target_in_range:
		target = target_in_range
	elif not unit.moves or not Goap.attack.can_hit(unit, target):
		target = null
		if unit.moves:
			var enemies_in_sight = unit.get_units_in_sight({"team": unit.opponent_team()})
			target = Goap.attack.select_target(unit, enemies_in_sight)
	Goap.attack.set_target(unit, target)
	var has_target = Goap.attack.can_hit(unit, target)
	agent.set_state("enemy_dead", false)
	agent.set_state("enemy_in_attack_range", has_target and Goap.attack.in_range(unit, target))
	return has_target


func priority(_agent) -> int:
	return 4


func get_desired_state(_agent) -> Dictionary:
	return {"enemy_dead": true}
