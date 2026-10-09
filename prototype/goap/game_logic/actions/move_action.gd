extends "res://goap/goap_system/action_contract.gd"

const teleport_time = 3
const teleport_max_distance = 100


func get_class_name() -> String:
	return "MoveAction"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return (
		unit.moves
		and unit.state == "move"
		and unit.current_destiny != Vector2.ZERO
		and not agent.get_state("has_path", false)
	)


func get_preconditions() -> Dictionary:
	return {"has_path": false}


func get_effects() -> Dictionary:
	return {"arrived_at_destination": true}


func perform(agent, _delta) -> bool:
	return agent.get_state("arrived_at_destination", false)


func enter(agent):
	var unit = agent.get_unit()
	agent.set_state("arrived_at_destination", false)
	move(unit, unit.current_destiny)


func setup_timer(unit):
	unit.channeling_timer = Timer.new()
	unit.channeling_timer.one_shot = true
	unit.add_child(unit.channeling_timer)


func point(unit, destiny):
	if unit.moves and not unit.agent.get_state("is_stunned") and in_bounds(destiny):
		move(unit, destiny)


func in_bounds(target_point: Vector2) -> bool:
	var map = WorldState.get_state("map")
	var half_tile_size = map.tile_size / 2
	return (
		target_point.x > half_tile_size and
		target_point.y > half_tile_size and
		target_point.x < map.size.x - half_tile_size and
		target_point.y < map.size.y - half_tile_size
	)


func move(unit, destiny):
	if unit.moves and not unit.agent.get_state("is_stunned"):
		unit.current_destiny = destiny
		var current_speed = Goap.modifiers.get_value(unit, "speed")
		calc_step(unit, current_speed)
		var animations = unit.get_node_or_null("animations")
		if animations and "speed_scale" in animations:
			animations.speed_scale = current_speed / max(unit.speed, 0.0001)
		unit.set_state("move")


func calc_step(unit, speed):
	if speed > 0:
		var distance = unit.current_destiny - unit.global_position
		unit.angle = distance.angle()
		unit.current_step = Vector2(speed * cos(unit.angle), speed * sin(unit.angle))
		unit.mirror_look_at(unit.current_destiny)


func step(unit, delta):
	var velocity = unit.current_step
	if (
		Goap.use_native_movement
		and Goap.use_native_pathfinding
		and unit.advance_with_navigation(delta)
	):
		velocity = unit.current_step

	var motion = velocity * delta
	if not Goap.use_native_blocking:
		motion = _resolve_legacy_blocking(unit, motion)

	if unit is CharacterBody2D:
		if Goap.use_native_movement:
			unit.velocity = motion / delta if delta > 0 else Vector2.ZERO
			unit.move_and_slide()
		elif Goap.use_native_blocking:
			unit.move_and_collide(motion)
		else:
			unit.global_position += motion
	else:
		unit.global_position += motion


func _resolve_legacy_blocking(unit, motion: Vector2) -> Vector2:
	if motion == Vector2.ZERO or _can_move_to(unit, motion):
		return motion

	var resolved_motion := Vector2.ZERO
	var horizontal_motion := Vector2(motion.x, 0)
	var vertical_motion := Vector2(0, motion.y)
	if (
		horizontal_motion != Vector2.ZERO
		and _can_move_to(unit, resolved_motion + horizontal_motion)
	):
		resolved_motion += horizontal_motion
	if vertical_motion != Vector2.ZERO and _can_move_to(unit, resolved_motion + vertical_motion):
		resolved_motion += vertical_motion
	return resolved_motion


func _can_move_to(unit, motion: Vector2) -> bool:
	var destination = unit.global_position + unit.collision_position + motion
	var search_radius = (
		motion.length()
		+ unit.collision_radius
		+ Collisions.max_collision_radius
		+ Collisions.tile_size
	)
	for other in Collisions.get_units_in_radius(destination, search_radius):
		if other == unit or other.dead or not other.collide:
			continue
		var other_position = other.global_position + other.collision_position
		var minimum_distance = unit.collision_radius + other.collision_radius
		if destination.distance_squared_to(other_position) < minimum_distance * minimum_distance:
			return false
	return true


func resume(unit):
	if not unit.agent.get_state("is_stunned"):
		move(unit, unit.current_destiny)


func end(unit):
	if unit.agent.get_state("is_retreating"):
		unit.agent.set_state("is_retreating", false)
	stop(unit)


func stop(unit):
	unit.current_step = Vector2.ZERO
	if unit.current_destiny == unit.final_destiny:
		unit.final_destiny = Vector2.ZERO
	unit.current_destiny = Vector2.ZERO
	unit.set_state("idle")
	var animations = unit.get_node_or_null("animations")
	if animations and "speed_scale" in animations:
		animations.speed_scale = 1.0


func smart(unit, target_point):
	if not unit or not unit.agent:
		return
	if not unit.agent.get_state("stunned"):
		if target_point != Vector2.ZERO and unit.current_destiny != Vector2.ZERO:
			unit.final_destiny = target_point
		Goap.navigation.navigate_to(unit, target_point)


func teleport(unit, target_point):
	var agent = unit.agent
	var game = get_tree().get_current_scene()
	var ui = game.ui
	ui.unit_controls_panel.teleport_button.disabled = false
	ui.unit_controls_panel.teleport_button.button_pressed = false
	var building = Utils.closer_building(target_point, unit.team)
	var distance = building.global_position.distance_to(target_point)
	Goap.move.stop(unit)
	agent.set_state("is_channeling", true)
	var order_id = agent.get_state("player_order_id", 0)
	var delay = Timer.new()
	delay.one_shot = true
	delay.wait_time = teleport_time
	unit.add_child(delay)
	delay.start()
	await delay.timeout
	if is_instance_valid(delay):
		delay.queue_free()
	if agent.get_state("is_channeling") and agent.get_state("player_order_id", 0) == order_id:
		agent.set_state("is_channeling", false)
		var new_position = target_point
		var min_distance = 2 * building.collision_radius + unit.collision_radius
		if distance <= min_distance:
			var offset = (target_point - building.global_position).normalized()
			new_position = building.global_position + (offset * min_distance)
		if distance > teleport_max_distance:
			var offset = (target_point - building.global_position).normalized()
			new_position = building.global_position + (offset * teleport_max_distance)

		unit.global_position = new_position
		agent.set_state("lane", building.lane)
		Goap.get_action("OrderAction").complete_player_order(agent)
		Goap.navigation.resume_lane(unit)
