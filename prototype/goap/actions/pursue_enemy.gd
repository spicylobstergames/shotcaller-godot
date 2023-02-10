extends "../Action.gd"


func get_class(): return "PursueEnemy"


func is_valid(agent) -> bool:
	return agent.get_state("has_attack_target")


func get_cost(agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {} # has target


func get_effects() -> Dictionary:
	return { "has_attack_target": false }


func perform(agent, delta) -> bool:
	return not agent.get_unit().target


func enter(agent):
	var unit = agent.get_unit()
	
#	if agent.get_state("command_attack_target"):
#		Behavior.attack.set_target(unit, agent.get_state("command_attack_target"))
#		Behavior.advance.point(unit, unit.target.position)
#
#	else:
	Behavior.advance.point(unit, unit.target.global_position)


func end(agent):
	var unit = agent.get_unit()
	Behavior.move.stop(unit)
