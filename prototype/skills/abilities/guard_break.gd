extends Node

@onready var unit: Unit = get_parent().get_parent().get_parent()


@export var icon: Texture2D
@export var ability_name = "Guard Break"
@export var description = "Arthur hits the guard in front of him and stuns the enemy" # (String, MULTILINE)
@export var active_skill_icon : Texture2D
@export var skill_type = "active"
@export var cooldown = 15
@export var visualize = "rectangle"
@export var attributes = {
	"length": 25, 
	"width": 10, 
	"center_pos": Vector2(0, 8), 
	"finish_pos": Vector2(300, 0), 
	"color": Color(0,0,100,0.05)
}


func arthur_active(effects, parameters, _visualize):
	var game:Node = get_tree().get_current_scene()
	var leader = WorldState.get_state("selected_leader")
	var point_target = await game.ui.active_skills._get_point_target(leader, effects, parameters, _visualize)
	if point_target == null:
		return false
	var polygon = game.ui.active_skills.generate_rect_poly(parameters.length, parameters.width, leader.global_position, point_target, parameters.color)
	var targets = game.ui.active_skills.enemies_in_polygon(leader, parameters.length, polygon)
	var damage = 10 * leader.level
	if targets.is_empty():
		return true
	for target in targets:
		Behavior.attack.take_hit(leader, target, null, { "damage": damage })
		target.start_stun()
	return true
