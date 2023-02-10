extends "../Action.gd"


func get_class(): return "AttackEnemy"


func is_valid(agent) -> bool:
	var target_enemy = agent.get_state("has_attack_target")
	var command_attack = agent.get_state("command_attack_target")
	return command_attack or target_enemy


func get_cost(agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return { "has_attack_target": false }


func perform(agent, delta) -> bool:
	return not agent.get_state("has_attack_target")


func enter(agent):
	#print("attack_enemy enter ", agent.get_unit())
	var unit = agent.get_unit()
	var target = unit.target
	if agent.get_state("command_attack_target"):
		Behavior.attack.set_target(unit, agent.get_state("command_attack_target"))
		Behavior.attack.point(unit, target.position)
	
	elif Behavior.attack.is_valid_target(unit, target):
		Behavior.attack.point(unit, target.global_position)


func on_animation_end(agent):
	var unit = agent.get_unit()
	
	if unit.agent.get_state("has_attack_target"):
		Behavior.advance.point(unit, unit.target.global_position)
	else:
		Behavior.move.stop(unit)  



func exit(agent):
	var unit = agent.get_unit()
	agent.clear_commands()
	Behavior.move.stop(unit)



