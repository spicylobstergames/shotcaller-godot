extends "res://goap/goap_system/goal_contract.gd"


func get_class_name() -> String:
	return "EnemyDefeated"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	var ready_to_fight = agent.get_state("ready_to_fight", true)
	if not ready_to_fight or not unit.attacks:
		return false

	var choose_target = Goap.get_action("ChooseTarget")
	var target = unit.target
	var has_target = (
		choose_target.can_hit(unit, target)
		and (unit.moves or choose_target.in_range(unit, target))
	)
	if not has_target:
		var enemies = unit.get_units_in_sight({"team": unit.opponent_team()})
		has_target = choose_target.select_target(unit, enemies) != null

	if has_target and agent.get_state("enemy_dead", false):
		agent.set_state("enemy_dead", false)
	return has_target


func priority(_agent) -> int:
	return 6


func get_desired_state(_agent) -> Dictionary:
	return {"enemy_dead": true}
