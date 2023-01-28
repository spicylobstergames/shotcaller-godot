extends "../Action.gd"


func get_class(): return "AttackEnemy"


func is_valid(agent) -> bool:
	var target_enemy = agent.get_state("target_enemy_active")
	var command_attack = agent.get_state("command_attack_target")
	return command_attack or target_enemy


#presently a magic number... maybe use distance in the future
func get_cost(agent) -> int:
	return 3


func get_preconditions() -> Dictionary:
	return {}


func get_effects() -> Dictionary:
	return {
		"target_enemy_active": false,
		"command_attack_target": null,
	}


func perform(agent, delta) -> bool:
	return not agent.get_state("target_enemy_active")


func enter(agent):
	#print("attack_enemy enter ", agent.get_unit())
	var unit = agent.get_unit()
	if agent.get_state("command_attack_target"):
		Behavior.attack.set_target(unit, agent.get_state("command_attack_target"))
		Behavior.attack.point(unit, unit.target.position)
		return

	var enemies = unit.get_units_on_sight({"team": unit.opponent_team()})
	if enemies.size() > 0:
		var target = Behavior.orders.select_target(unit, enemies)
		if Behavior.attack.is_valid_target(unit, target):
			Behavior.attack.set_target(unit, target)
			Behavior.attack.point(unit, target.global_position)
	else :
		print('Attack enemy action but no target')



func on_attack_end(agent):
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_radius(unit.attack_hit_radius, {"team": unit.opponent_team()})
	var has_targets = enemies.size() > 0
	unit.agent.set_state("target_enemy_active", has_targets)
	
	if !has_targets:
		Behavior.move.stop(unit)
	elif unit.target:      
		Behavior.advance.point(unit, unit.target.global_position)


func exit(agent):
	var unit = agent.get_unit()
	agent.clear_commands()
	Behavior.move.stop(unit)



