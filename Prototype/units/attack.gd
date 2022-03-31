extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func start(unit, point):
	unit.look_at(point)
	unit.set_state("attack")


func hits(unit1, unit2):
	var attack_position = unit1.global_position + unit1.attack_hit_position
	var attack_radius = unit1.attack_hit_radius * unit1.current_attack_range
	return game.circle_collision(attack_position, attack_radius, unit2.global_position, unit2.collision_rad)


func end(unit1):
	var neighbors = game.map.quad.get_bodies_in_radius(unit1.attack_hit_position, unit1.attack_hit_radius)
	for unit2 in neighbors:
		if unit1 != unit2 and hits(unit1, unit2):
			unit2.take_hit(unit1)
	unit1.set_state("idle")
