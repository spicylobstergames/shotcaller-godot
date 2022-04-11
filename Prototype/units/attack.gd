extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func start(unit, point):
	if (unit.attacks):
		unit.look_at(point)
		unit.set_state("attack")
		unit.get_node("animations").playback_speed = unit.current_attack_speed
		if unit.ranged and unit.weapon:
			unit.weapon.look_at(point)
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
			
			take_hit(unit1, unit2, null)
			return # if no cleave


func in_range(attacker, target):
	var att_pos = attacker.global_position + attacker.attack_hit_position
	var att_rad = attacker.attack_hit_radius * attacker.current_attack_range
	var tar_pos = target.global_position + target.collision_position
	var tar_rad = target.collision_radius
	return game.utils.circle_collision(att_pos, att_rad, tar_pos, tar_rad)


func take_hit(attacker, target, projectile):
	if projectile: 
		projectile_stuck(attacker, target, projectile)
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


func projectile_start(attacker):
	var projectile_node = attacker.projectile.duplicate()
	var a = attacker.weapon.global_rotation
	var speed = attacker.projectile_speed
	var projectile_speed = Vector2(cos(a)*speed, sin(a)*speed)
	var lifetime = attacker.attack_hit_radius / attacker.projectile_speed
	projectile_node.global_position = attacker.projectile.global_position
	projectile_node.global_rotation = a
	projectile_node.visible = true
	game.map.add_child(projectile_node)
	var projectile = {
		"node": projectile_node,
		"speed": projectile_speed,
		"lifetime": lifetime
	}
	attacker.projectiles.append(projectile)


func projectile_stuck(attacker, target, projectile):
	var stuck = projectile.node
	var r = projectile.node.global_rotation
	if target: 
		stuck = projectile.node.duplicate()
		stuck.global_position = Vector2.ZERO
		if target and target.mirror: r = Vector2(cos(r),-sin(r)).angle()
		target.get_node("sprites").add_child(stuck)
		game.map.remove_child(projectile.node)
		projectile.node.queue_free()
		
	var a = 0.2 # angle variation
	stuck.global_rotation = r + ((randf()*a*2)-a) # some angle variation
	stuck.frame = 1 # stuck sprite
	
	attacker.projectiles.erase(projectile)
	
	yield(get_tree().create_timer(2.0), "timeout")
	
	if target: target.get_node("sprites").remove_child(stuck)
	else: game.map.remove_child(stuck)
	
	stuck.queue_free()
