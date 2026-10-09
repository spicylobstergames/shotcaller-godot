extends "res://goap/goap_system/action_contract.gd"

const DEFAULT_PRIORITY = ["pawn", "leader", "building"]

var player_lane_priorities := {}
var enemy_lane_priorities := {}
var player_leader_priorities := {}
var enemy_leader_priorities := {}


func get_class_name() -> String:
	return "ChooseTarget"


func is_valid(_agent) -> bool:
	return false


func build_lane_priorities(lanes: Array) -> void:
	player_lane_priorities.clear()
	enemy_lane_priorities.clear()
	for lane in lanes:
		player_lane_priorities[lane.name] = DEFAULT_PRIORITY.duplicate()
		enemy_lane_priorities[lane.name] = DEFAULT_PRIORITY.duplicate()


func build_leader_priorities(player_leaders: Array, enemy_leaders: Array) -> void:
	player_leader_priorities.clear()
	enemy_leader_priorities.clear()
	for leader in player_leaders:
		player_leader_priorities[leader.name] = DEFAULT_PRIORITY.duplicate()
	for leader in enemy_leaders:
		enemy_leader_priorities[leader.name] = DEFAULT_PRIORITY.duplicate()


func set_lane_priority(lane: String, team: String, target_type: String) -> void:
	var priorities = _lane_priorities(team)
	if not priorities.has(lane):
		priorities[lane] = DEFAULT_PRIORITY.duplicate()
	_move_priority_first(priorities[lane], target_type)


func set_leader_priority(leader, target_type: String) -> void:
	var priorities = _leader_priorities(leader.team)
	if not priorities.has(leader.name):
		priorities[leader.name] = DEFAULT_PRIORITY.duplicate()
	_move_priority_first(priorities[leader.name], target_type)


func set_unit_priority(unit) -> void:
	if not unit.agent:
		return
	var priorities: Array = DEFAULT_PRIORITY
	if unit.type == "leader":
		var leader_priorities = _leader_priorities(unit.team)
		if not leader_priorities.has(unit.name):
			leader_priorities[unit.name] = DEFAULT_PRIORITY.duplicate()
		priorities = leader_priorities[unit.name]
	else:
		var lane = unit.agent.get_state("lane", "")
		var lane_priorities = _lane_priorities(unit.team)
		if not lane_priorities.has(lane):
			lane_priorities[lane] = DEFAULT_PRIORITY.duplicate()
		priorities = lane_priorities[lane]
	unit.agent.set_state("target_priority", priorities.duplicate())


func apply_building_priorities() -> void:
	for building in WorldState.get_state("all_buildings"):
		set_unit_priority(building)


func _lane_priorities(team: String) -> Dictionary:
	return (
		player_lane_priorities
		if team == WorldState.get_state("player_team")
		else enemy_lane_priorities
	)


func _leader_priorities(team: String) -> Dictionary:
	return (
		player_leader_priorities
		if team == WorldState.get_state("player_team")
		else enemy_leader_priorities
	)


func _move_priority_first(priorities: Array, target_type: String) -> void:
	if target_type not in priorities:
		return
	priorities.erase(target_type)
	priorities.push_front(target_type)


func closest_enemy_unit(unit, enemies):
	var filtered = []
	for enemy in enemies:
		if can_hit(unit, enemy):
			filtered.append(enemy)
	var sorted = unit.sort_by_distance(filtered)
	if sorted:
		return sorted[0].unit


func select_target(unit, enemies):
	var filtered = []
	for enemy in enemies:
		if can_hit(unit, enemy):
			filtered.append(enemy)
	if filtered.is_empty():
		return null
	if filtered.size() == 1:
		return filtered[0]
	var sorted = unit.sort_by_distance(filtered)
	var closest_unit = sorted[0].unit
	var priorities = unit.agent.get_state("target_priority", DEFAULT_PRIORITY)
	if filtered.size() == 2:
		var further_unit = sorted[1].unit
		var index1 = priorities.find(closest_unit.type)
		var index2 = priorities.find(further_unit.type)
		if index2 < index1:
			return further_unit
	if not unit.ranged:
		return closest_unit
	for priority_type in priorities:
		for enemy in sorted:
			if enemy.unit.type == priority_type:
				return enemy.unit
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
