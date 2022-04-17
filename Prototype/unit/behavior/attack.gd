extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func start(unit, point):
	if unit.attacks:
		unit.look_at(point)
		unit.set_state("attack")
		unit.get_node("animations").playback_speed = unit.current_attack_speed
		if unit.ranged and unit.weapon:
			unit.weapon.look_at(point)
		if !unit.target:
			var neighbors = game.map.blocks.get_units_in_radius(point, 1)
			if neighbors:
				var target = closest_enemy_unit(unit, neighbors)
				if target and (target.global_position - point).length() <= target.collision_radius:
					unit.target = target


func closest_enemy_unit(unit, enemies):
	var sorted = game.utils.sort_by_distance(unit, enemies)
	var filtered = []
	for enemy in sorted:
		if enemy.unit.team != game.player_team:
			filtered.append(enemy.unit)
	if filtered:
		return filtered[0]


func hit(unit1):
	var att_pos = unit1.global_position + unit1.attack_hit_position
	var att_rad = unit1.attack_hit_radius
	
	var neighbors = game.map.blocks.get_units_in_radius(att_pos, att_rad)
	var target_hit = false
	for unit2 in neighbors:
		if (unit1 != unit2 and 
				unit2.hp and 
				unit2 == unit1.target and  # or unit1 has cleave
				in_range(unit1, unit2)):
			take_hit(unit1, unit2, null)
			target_hit = true
			break # if no cleave
			
	if not target_hit and neighbors.size():
		var target = closest_enemy_unit(unit1, neighbors)
		if target and (target.global_position - att_pos).length() <= target.collision_radius:
			take_hit(unit1, target, null)
		
		

func in_range(attacker, target):
	var att_pos = attacker.global_position + attacker.attack_hit_position
	var att_rad = attacker.attack_hit_radius * attacker.current_attack_range
	var tar_pos = target.global_position + target.collision_position
	var tar_rad = target.collision_radius
	return game.utils.circle_collision(att_pos, att_rad, tar_pos, tar_rad)


func take_hit(attacker, target, projectile):
	if projectile: 
		projectile_stuck(attacker, target, projectile)
	if target and target.current_hp > 0:
		target.current_hp -= attacker.damage
		game.unit.advance.react(target, attacker)
		game.unit.advance.ally_attacked(target, attacker)
		game.unit.orders.take_hit(attacker, target)
		game.unit.hud.update_hpbar(target)
		if target == game.selected_unit: game.ui.stats.update()
		if target.current_hp <= 0: 
			target.current_hp = 0
			target.die()
			if target.type == "leader":
				if target.team == game.player_team: game.player_deaths += 1
				else: game.enemy_deaths += 1
				if attacker.team == game.player_team: game.player_kills += 1
				else: game.enemy_kills += 1
			yield(get_tree().create_timer(0.6), "timeout")
			game.unit.advance.resume(attacker)


func projectile_start(attacker):
	var projectile = attacker.projectile.duplicate()
	var projectile_sprite = projectile.get_node("sprites")
	var a = attacker.weapon.global_rotation
	var speed = attacker.projectile_speed
	var projectile_speed = Vector2(cos(a)*speed, sin(a)*speed)
	var lifetime = attacker.attack_hit_radius / attacker.projectile_speed
	projectile.global_position = attacker.projectile.global_position
	var projectile_rotation
	if attacker.projectile_rotation:
		projectile_rotation = attacker.projectile_rotation
		if attacker.mirror:
			a -= PI
			projectile_rotation *= -1
			projectile_sprite.scale.x *= -1
	projectile.global_rotation = a
	projectile_sprite.visible = true
	game.map.add_child(projectile)
	attacker.projectiles.append({
		"node": projectile,
		"sprite": projectile_sprite,
		"speed": projectile_speed,
		"rotation": projectile_rotation,
		"lifetime": lifetime
	})


func projectile_step(delta, projectile):
	if projectile.speed:
		projectile.node.global_position += projectile.speed * delta
	
	if projectile.rotation:
		projectile.node.global_rotation += projectile.rotation * delta


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
	var ra = (randf()*a*2) - a
	stuck.global_rotation = r + ra # some angle variation
	
	# rotating axe
	if projectile.rotation:
		if (target and target.mirror):
			stuck.global_rotation = 0 + ra
			stuck.scale.x *= -1
		else: 
			stuck.global_rotation = PI + ra
		var o = projectile.speed*-0.08
		stuck.global_position += o
		
	stuck.get_node("sprites").frame = 1 # stuck sprite
	attacker.projectiles.erase(projectile)
	
	yield(get_tree().create_timer(1.2), "timeout")
	
	if target: target.get_node("sprites").remove_child(stuck)
	else: game.map.remove_child(stuck)
	stuck.queue_free()
