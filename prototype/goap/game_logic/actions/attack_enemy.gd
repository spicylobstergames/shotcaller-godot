extends "res://goap/goap_system/action_contract.gd"


func get_class_name(): return "AttackEnemy"


func is_valid(agent) -> bool:
	return !!agent.get_state("has_attack_target")
	
	
func get_cost(_agent) -> int:
	return 1


func get_effects() -> Dictionary:
	return { "has_attack_target": false }


func perform(agent, _delta) -> bool:
	return not agent.get_state("has_attack_target")


func enter(agent):
	var unit = agent.get_unit()
	var target = unit.target
	
	if Goap.attack.is_valid_target(unit, target):
		Goap.advance.point(unit, target.global_position)


func on_animation_end(agent):
	var unit = agent.get_unit()
	var target = unit.target
	
	if unit.agent.get_state("has_attack_target"):
		Goap.advance.point(unit, target.global_position)
	else:
		Goap.move.stop(unit)



func exit(agent):
	var unit = agent.get_unit()
	Goap.move.stop(unit)



