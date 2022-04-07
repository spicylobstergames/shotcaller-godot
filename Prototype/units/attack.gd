extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func start(unit, point):
	if (unit.attacks):
		unit.look_at(point)
		unit.aim_point = point
		unit.set_state("attack")
		if unit.ranged and unit.weapon:
			unit.weapon.look_at(unit.aim_point)
		if !unit.target:
			unit.target = get_first_target(point)


func get_first_target(point):
	var neighbors = game.map.blocks.get_units_in_radius(point, 1)
	for unit in neighbors:
		return unit


func hit(unit1):
	var att_pos = unit1.global_position + unit1.attack_hit_position
	var att_rad = unit1.attack_hit_radius
	var neighbors = game.map.blocks.get_units_in_radius(att_pos, att_rad)
	for unit2 in neighbors:
		
		if (unit1 != unit2 and 
				unit2.hp and 
				unit2 == unit1.target and  # or unit1 has cleave
				in_range(unit1, unit2)):
			
			take_hit(unit1, unit2)
			return # if no cleave


func in_range(attacker, target):
	var att_pos = attacker.global_position + attacker.attack_hit_position
	var att_rad = attacker.attack_hit_radius * attacker.current_attack_range
	var tar_pos = target.global_position + target.collision_position
	var tar_rad = target.collision_radius
	return game.utils.circle_collision(att_pos, att_rad, tar_pos, tar_rad)


func take_hit(attacker, target):
	if attacker.projectile: 
		projectile_stuck(attacker, target)
		attacker.projectile.visible = false
	target.current_hp -= attacker.damage
	game.unit.advance.react(target, attacker)
	game.unit.advance.ally_attacked(target, attacker)
	game.ui.update_hpbar(target)
	if target == game.selected_unit: game.ui.update_stats()
	if target.current_hp <= 0: 
		target.current_hp = 0
		target.die()
		yield(get_tree().create_timer(0.6), "timeout")
		game.unit.advance.resume(attacker)


func projectile_stuck(attacker, target):
	var pos = attacker.projectile.global_position - target.global_position
	var stuck = attacker.projectile.duplicate()
	var a = 0.2 # adjust
	var r = attacker.weapon.global_rotation
	stuck.global_rotation = r + ((randf()*a*2)-a) # some angle variation
	stuck.position = pos * a # goes a bit deeper
	stuck.frame = 1
	target.get_node("sprites").add_child(stuck)
	yield(get_tree().create_timer(12.0), "timeout")
	stuck.queue_free()
