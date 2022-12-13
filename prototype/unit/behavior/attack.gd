extends Node
var game:Node

# self = Behavior.attack

func _ready():
	game = get_tree().get_current_scene()


func point(unit, point):
	if unit.attacks and not unit.stunned and not unit.command_casting and Behavior.move.in_bounds(point):

		if unit.ranged and unit.weapon:
			unit.weapon.look_at(point)
		
		if !unit.target:
			var neighbors = game.map.blocks.get_units_in_radius(point, 1)
			if neighbors:
				var target = closest_enemy_unit(unit, neighbors)
				if can_hit(unit, target) and in_range(unit, target):
					Behavior.attack.set_target(unit, target)
		
		if unit.target or game.test.unit:
			unit.aim_point = point
			unit.look_at(point)
			unit.get_node("animations").playback_speed = Behavior.modifiers.get_value(unit, "attack_speed")
			unit.set_state("attack")
			
		else: Behavior.advance.resume(unit)


func set_target(unit, target):
	if not target: 
		unit.hunting = false
		unit.attack_count = 0
		Behavior.modifiers.remove(unit, "attack_speed", "agile")
	if target and unit.moves: unit.hunting = true
	if unit.target != target:
		unit.attack_count = 0
		Behavior.modifiers.remove(unit, "attack_speed", "agile")
		unit.last_target = unit.target
	unit.target = target


func closest_enemy_unit(unit, enemies):
	var filtered = []
	
	for enemy in enemies:
		if can_hit(unit, enemy): filtered.append(enemy)
	
	var sorted = unit.sort_by_distance(filtered)
	
	if sorted: return sorted[0].unit


func hit(unit1):
	var att_pos = unit1.global_position + unit1.attack_hit_position
	var att_rad = unit1.attack_hit_radius
	
	# hit target
	if can_hit(unit1, unit1.target) and in_range(unit1, unit1.target):
		take_hit(unit1, unit1.target)
	
	# melee cleave damage
	if unit1.display_name in Behavior.skills.leader:
		var attacker_skills = Behavior.skills.leader[unit1.display_name]
		if "cleave" in attacker_skills:
			var neighbors = game.map.blocks.get_units_in_radius(att_pos, att_rad)
			for unit2 in neighbors:
				if can_hit(unit1, unit2) and in_range(unit1, unit2):
					take_hit(unit1, unit2, null, {"cleave": true})


func can_hit(attacker, target):
	return (
		attacker != null and
		target != null and
		target != attacker and
		target.team != attacker.team and
		target.type != "block" and
		is_instance_valid(attacker) and
		is_instance_valid(target) and
		not target.dead and
		not target.immune
	)


func in_range(attacker, target):
	var att_pos = attacker.global_position + attacker.attack_hit_position
	var att_rad = Behavior.modifiers.get_value(attacker, "attack_range")
	var tar_pos = target.global_position + target.collision_position
	var tar_rad = target.collision_radius
	return game.utils.circle_collision(att_pos, att_rad, tar_pos, tar_rad)


func take_hit(attacker, target, projectile = null, modifiers = {}):
	modifiers = Behavior.skills.hit_modifiers(attacker, target, projectile, modifiers)
	
	if projectile:
		if not modifiers.pierce: 
			projectile_stuck(attacker, target, projectile)
		
		if projectile.targets != null and projectile.targets.find(target) < 0:
			projectile.targets.append(target)
	
	if target and not target.dead and not target.immune:
		if not modifiers.dodge:
			var damage = max(1, modifiers.damage - Behavior.modifiers.get_value(target, "defense"))
			target.current_hp -= damage
			attacker.attack_count += 1
			if attacker.type == "leader":
				target.last_attacker = attacker
				target.assist_candidates[attacker] = OS.get_ticks_msec()
			
		if not modifiers.counter:
			Behavior.advance.react(target, attacker)
			Behavior.advance.ally_attacked(target, attacker)
			
		Behavior.orders.take_hit_retreat(attacker, target)
		if target.hud: Hud.update_hpbar(target)
		if target == game.selected_unit: game.ui.stats.update()
		
		if (target.type == "building" and 
				target.subtype == "backwood"):
				
				var hp = Behavior.modifiers.get_value(target, "hp")
				var rate = float(target.current_hp)/float(hp)
				
				var tax = Behavior.orders.player_tax
				if target.team == game.enemy_team:
					tax = Behavior.orders.enemy_tax
					
				var limit = Behavior.orders.tax_conquer_limit[tax]
				
				if rate <= limit:
					Behavior.orders.lose_building(target)
		
		if target.current_hp <= 0: 
			target.current_hp = 0
			target.die()
			if target.type == "leader":
				if target.team == game.player_team: game.player_deaths += 1
				else: game.enemy_deaths += 1
				if attacker.team == game.player_team: game.player_kills += 1
				else: game.enemy_kills += 1
			yield(get_tree().create_timer(0.6), "timeout")
			Behavior.attack.set_target(attacker, null)
			Behavior.advance.resume(attacker)



func projectile_release(attacker):
	projectile_start(attacker, attacker.target)
	Behavior.skills.projectile_release(attacker)



func projectile_start(attacker, target):
	var target_position = attacker.aim_point
	if target:
		target_position = target.global_position + target.collision_position
		if target.dead or target.immune: return
	if not Behavior.move.in_bounds(target_position): return
	attacker.weapon.look_at(target_position)
	var projectile = attacker.projectile.duplicate()
	game.map.add_child(projectile)
	var projectile_sprite = projectile.get_node("sprites")
	projectile.global_position = attacker.projectile.global_position
	projectile.visible = true
	projectile_sprite.visible = true
	# speed
	var a = attacker.weapon.global_rotation
	var speed = attacker.projectile_speed
	var projectile_speed = Vector2(cos(a)*speed, sin(a)*speed)
	# rotation
	var projectile_rotation
	if attacker.projectile_rotation:
		projectile_rotation = attacker.projectile_rotation
		if attacker.mirror:
			a -= PI
			projectile_rotation *= -1
			projectile_sprite.scale.x *= -1
	projectile.global_rotation = a
	# piercing target array
	var targets = null
	if attacker.display_name in Behavior.skills.leader:
		var attacker_skills = Behavior.skills.leader[attacker.display_name]
		if "pierce" in attacker_skills: 
			target = null
	if not target: targets = []
	var radius = Behavior.modifiers.get_value(attacker, "attack_range") + 20
	attacker.projectiles.append({
		"target": target,
		"targets": targets,
		"node": projectile,
		"sprite": projectile_sprite,
		"speed": projectile_speed,
		"rotation": projectile_rotation,
		"radius": radius,
		"stuck": false
	})


func projectile_step(delta, projectile):
	if not projectile.stuck:
		if projectile.speed:
			projectile.node.global_position += projectile.speed * delta
		
		if projectile.rotation:
			projectile.node.global_rotation += projectile.rotation * delta


func projectile_stuck(attacker, target, projectile):
	projectile.stuck = true
	var stuck = projectile.node
	var sprites = stuck.get_node("sprites")
	var r = projectile.node.global_rotation
	
	if target: 
		stuck.get_parent().remove_child(stuck)
		target.get_node("sprites/stuck").add_child(stuck)
		stuck.global_position = target.global_position + target.collision_position
		if target.mirror: 
			r = Vector2(cos(r),-sin(r)).angle()
		
	var a = 0.2 # rad angle variation
	var ra = (randf()*a*2) - a
	stuck.global_rotation = r + ra
	
	# rotating axe
	if projectile.rotation == 20:
		stuck.global_rotation = 0 + ra
		if target:
			# mirror stuck axe
			if target.mirror:
				stuck.global_rotation = PI + ra
				stuck.scale.x *= -1
		# offset from center
		sprites.offset.x = -10
		stuck.global_position -= projectile.speed*0.03
	
	# stuck sprite
	sprites.frame = 1 
	# stop projectile movement
	attacker.projectiles.erase(projectile)
	# remove projectile after 1.2 sec

	yield(get_tree().create_timer(1.2), "timeout")
	if is_instance_valid(stuck):
		stuck.get_parent().remove_child(stuck)
		stuck.queue_free()


func clear_stuck(unit):
	var node = unit.get_node("sprites/stuck")
	for n in node.get_children():
		node.remove_child(n)
		n.queue_free()

