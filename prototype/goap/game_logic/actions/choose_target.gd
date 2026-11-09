extends "res://goap/goap_system/action_contract.gd"


func get_class_name() -> String:
	return "ChooseTarget"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.attacks and !unit.target


#func get_cost(_agent) -> int:
#	return 1


func get_preconditions() -> Dictionary:
	return {"is_stunned": false}


func get_effects() -> Dictionary:
	return {"has_attack_target": true}



func enter(agent):
	var unit = agent.get_unit()
	var enemies = unit.get_units_in_sight({ "team": unit.opponent_team() })
	var target = select_target(unit, enemies)
	set_target(agent, target)


func perform(_agent, _delta) -> bool:
	return true # is_step_complete


#func exit(_agent) :
#	pass


func select_target(unit, enemies):
	var filtered = []
	for enemy in enemies:
		if can_hit(unit, enemy) and (unit.moves or in_range(unit, enemy)):
			filtered.append(enemy)
	if filtered.is_empty():
		return null
	if filtered.size() == 1:
		return filtered[0]
	var sorted = unit.sort_by_distance(filtered)
	var closest_unit = sorted[0].unit
	
	return closest_unit


func can_hit(attacker, target) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	return (
		target != attacker
		and target.team != attacker.team
		and target.type != "block"
		and not target.dead
		and not target.immune
	)


func in_range(attacker, target) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	var att_pos = attacker.global_position + attacker.attack_hit_position
	var att_rad = Modifiers.get_value(attacker, "attack_range")
	var tar_pos = target.global_position + target.collision_position
	var tar_rad = target.collision_radius
	return Utils.circle_collision(att_pos, att_rad, tar_pos, tar_rad)


func is_valid_target(attacker, target) -> bool:
	return can_hit(attacker, target) and in_range(attacker, target)



func set_target(agent, value) -> void:
	var unit = agent.get_unit()
	var target = value if is_instance_valid(value) else null
	var previous_target = unit.target
	if previous_target != target:
		unit.last_target = previous_target
	if previous_target != target or target == null:
		unit.attack_count = 0
		Modifiers.remove(unit, "attack_speed", "agile")
		unit.target = target
	if target:
		agent.set_state("enemy_dead", false)
		
	agent.set_state("has_attack_target", target != null)
	agent.set_state("hunting", target != null)
