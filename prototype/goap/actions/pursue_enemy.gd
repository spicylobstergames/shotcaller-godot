extends "../Action.gd"


func get_class_name(): return "PursueEnemy"


func is_valid(agent) -> bool:
	return !!agent.get_state("has_attack_target")


func get_cost(_agent) -> int:
	return 1


func get_preconditions() -> Dictionary:
	return {} # has target


func get_effects() -> Dictionary:
	return { "has_attack_target": false }


func perform(agent, _delta) -> bool:
	return not agent.get_unit().target


func enter(agent):
	var unit = agent.get_unit()
	Behavior.advance.point(unit, unit.target.global_position)


func end(agent):
	var unit = agent.get_unit()
	Behavior.move.stop(unit)
