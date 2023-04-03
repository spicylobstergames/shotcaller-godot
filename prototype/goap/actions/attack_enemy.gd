extends "../Action.gd"


func get_class_name(): return "AttackEnemy"


func is_valid(agent) -> bool:
	return agent.get_state("has_attack_target")
	
	
func get_cost(agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return { "has_attack_target": false }


func perform(agent, delta) -> bool:
	return not agent.get_state("has_attack_target")


func enter(agent):
	var unit = agent.get_unit()
	var target = unit.target
	
	if Behavior.attack.is_valid_target(unit, target):
		Behavior.attack.point(unit, target.global_position)


func on_animation_end(agent):
	var unit = agent.get_unit()
	var target = unit.target
	
	if unit.agent.get_state("has_attack_target"):
		Behavior.advance.point(unit, target.global_position)
	else:
		Behavior.move.stop(unit)  



func exit(agent):
	var unit = agent.get_unit()
	Behavior.move.stop(unit)



