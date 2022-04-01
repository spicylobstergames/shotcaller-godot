extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func start(unit, point):
	if (unit.attacks):
		unit.look_at(point)
		unit.set_state("attack")


func in_range(attacker, target):
	var att_pos = attacker.global_position + attacker.attack_hit_position
	var att_rad = attacker.attack_hit_radius * attacker.current_attack_range
	var tar_pos = target.global_position + target.collision_position
	var tar_rad = target.collision_radius
	return game.circle_collision(att_pos, att_rad, tar_pos, tar_rad)


func end(unit1):
	var att_pos = unit1.global_position + unit1.attack_hit_position
	var arr_rad = unit1.attack_hit_radius
	var neighbors = game.map.quad.get_units_in_radius(att_pos, arr_rad)
	for unit2 in neighbors:
		if unit1 != unit2 and in_range(unit1, unit2):
			take_hit(unit1, unit2)


func take_hit(attacker, target):
	target.current_hp -= attacker.damage
	game.ui.update_hpbar(target)
	if target == game.selected_unit: game.ui.update_stats()
	if target.current_hp <= 0: 
		target.current_hp = 0
		target.die()

