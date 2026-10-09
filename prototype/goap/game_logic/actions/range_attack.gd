extends "res://goap/goap_system/action_contract.gd"


func get_class_name() -> String:
	return "RangeAttack"


func projectile_release(attacker) -> void:
	projectile_start(attacker, attacker.target)
	Skills.projectile_release(attacker)


func projectile_start(attacker, target) -> void:
	var target_position = attacker.aim_point
	if target:
		target_position = target.global_position + target.collision_position
		if target.dead or target.immune:
			return
	if not Goap.move.in_bounds(target_position):
		return
	attacker.weapon.look_at(target_position)
	var projectile = attacker.projectile.duplicate()
	WorldState.get_state("map").projectile_container.add_child(projectile)
	var projectile_sprite = projectile.get_node_or_null("sprites")
	if projectile_sprite:
		projectile.global_position = attacker.projectile.global_position
		projectile.show()
		projectile_sprite.show()

	var angle = attacker.weapon.global_rotation
	var projectile_speed = Vector2(
		cos(angle) * attacker.projectile_speed, sin(angle) * attacker.projectile_speed
	)
	var projectile_rotation = attacker.projectile_rotation
	if projectile_rotation and attacker.mirror:
		angle -= PI
		projectile_rotation *= -1
		projectile_sprite.scale.x *= -1
	projectile.global_rotation = angle

	var targets = null
	if attacker.display_name in Skills.leader and "pierce" in Skills.leader[attacker.display_name]:
		target = null
	if not target:
		targets = []
	var radius = Modifiers.get_value(attacker, "attack_range") + 20
	attacker.projectiles.append(
		{
			"target": target,
			"targets": targets,
			"node": projectile,
			"sprite": projectile_sprite,
			"speed": projectile_speed,
			"rotation": projectile_rotation,
			"radius": radius,
			"stuck": false
		}
	)


func projectile_step(delta, projectile) -> void:
	if not projectile.stuck:
		if projectile.speed:
			projectile.node.global_position += projectile.speed * delta
		if projectile.rotation:
			projectile.node.global_rotation += projectile.rotation * delta


func projectile_stuck(attacker, target, projectile) -> void:
	projectile.stuck = true
	var stuck = projectile.node
	var sprites = stuck.get_node_or_null("sprites")
	var rotation = projectile.node.global_rotation

	if is_instance_valid(target) and is_instance_valid(stuck):
		var parent = stuck.get_parent()
		if parent:
			parent.remove_child(stuck)
		var stuck_container = target.get_node_or_null("sprites/stuck")
		if stuck_container:
			stuck_container.add_child(stuck)
			stuck.global_position = target.global_position + target.collision_position
			if target.mirror:
				rotation = Vector2(cos(rotation), -sin(rotation)).angle()

	var angle_variation = 0.2
	var random_angle = (randf() * angle_variation * 2) - angle_variation
	stuck.global_rotation = rotation + random_angle

	if projectile.rotation == 20:
		stuck.global_rotation = random_angle
		if target and target.mirror:
			stuck.global_rotation = PI + random_angle
			stuck.scale.x *= -1
		sprites.offset.x = -10
		stuck.global_position -= projectile.speed * 0.03

	sprites.frame = 1
	attacker.projectiles.erase(projectile)

	await Goap.get_tree().create_timer(1.2).timeout
	if is_instance_valid(stuck):
		var parent = stuck.get_parent()
		if parent:
			parent.remove_child(stuck)
		stuck.queue_free()


func clear_stuck(unit) -> void:
	var stuck_node = unit.get_node_or_null("sprites/stuck")
	if stuck_node:
		for projectile in stuck_node.get_children():
			stuck_node.remove_child(projectile)
			projectile.queue_free()
