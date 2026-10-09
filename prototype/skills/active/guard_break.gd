extends Node

@export var skill_data: SkillResource


func arthur_active(effects: Dictionary, parameters: Dictionary, _visualize: bool) -> bool:
	var game: Node = get_tree().get_current_scene()
	var leader = WorldState.get_state("selected_leader")
	var point_target = await game.ui.active_skills._get_point_target(leader, effects, parameters, _visualize)
	if point_target == null:
		return false
	var polygon = game.ui.active_skills.generate_rect_poly(parameters.length, parameters.width, leader.global_position, point_target, parameters.color)
	var targets = game.ui.active_skills.enemies_in_polygon(leader, parameters.length, polygon)
	var damage: int = skill_data.attributes.damage_per_level * leader.level
	if targets.is_empty():
		return true
	for target in targets:
		Goap.get_goal("EnemyDefeated").take_hit(leader, target, null, {"damage": damage})
		target.start_stun()
	return true
