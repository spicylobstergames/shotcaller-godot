extends Node


# self = Behavior.move

const teleport_time = 3
const teleport_max_distance = 100


func setup_timer(unit):
	unit.collision_timer = Timer.new()
	unit.collision_timer.one_shot = true
	unit.add_child(unit.collision_timer)
	
	unit.channeling_timer = Timer.new()
	unit.channeling_timer.one_shot = true
	unit.add_child(unit.channeling_timer)


func point(unit, destiny):
	if unit.moves and not unit.agent.get_state("is_stunned") and in_bounds(destiny):
		move(unit, destiny)


func in_bounds(p):
	var l = WorldState.get_state("map").tile_size / 2
	return p.x > l and p.y > l and p.x < WorldState.get_state("map").size.x - l and p.y < WorldState.get_state("map").size.y - l



func move(unit, destiny):
	if (
		unit.moves
		and not unit.agent.get_state("is_stunned")
	):
		unit.current_destiny = destiny
		var current_speed = Behavior.modifiers.get_value(unit, "speed")
		calc_step(unit, current_speed)
		unit.get_node("animations").speed_scale = current_speed / unit.speed
		unit.set_state("move")



func calc_step(unit, speed):
	if speed > 0:
		var distance = unit.current_destiny - unit.global_position
		unit.angle = distance.angle()
		unit.current_step = Vector2(speed* cos(unit.angle), speed * sin(unit.angle))
		unit.mirror_look_at(unit.current_destiny)



func step(unit, delta):	
	unit.global_position += unit.current_step * delta


func on_collision(unit, _delta):
	var target = unit.collide_target
	if target and target != unit.target:
		var a # new direction
		var p1 = unit.global_position + unit.collision_position
		var p2 = target.global_position + target.collision_position
		var pr = p2 - p1 # relative target position
		var ang_to_target = pr.angle() # target relative angle
		# angle between direction and target
		var rda = Utils.limit_angle(unit.angle - ang_to_target) 
		# new direction: rotates pr +-90 deg (tangent direction)
		if (rda > 0): a = Vector2(-pr.y, pr.x).angle()
		else: a = Vector2(pr.y, -pr.x).angle()
		# if stuck slide away and try new direction
		if unit.global_position == unit.last_position2:
			unit.global_position -= pr.normalized()
			a = randf()*2*PI # just try a random direction
		unit.angle = a # change directioin
		var s = Behavior.modifiers.get_value(unit, "speed")
		unit.current_step = Vector2(s * cos(a), s * sin(a))
		# send back to original destiny after some time
		if unit.collision_timer.time_left > 0: 
			unit.collision_timer.stop() # first stops previous timers
		unit.collision_timer.wait_time = 0.2 + randf() * 0.1
		unit.collision_timer.start()
		
		await unit.collision_timer.timeout
		#current_destiny does have the potential to change in the time between
		move(unit, unit.current_destiny)		



func resume(unit):
	if not unit.agent.get_state("is_stunned"):
		move(unit, unit.current_destiny)


func end(unit):
	if unit.agent.get_state("is_retreating"):
		unit.agent.set_state("is_retreating", false)
	stand(unit)
	

func stop(unit):
	unit.current_step = Vector2.ZERO
	if unit.current_destiny == unit.final_destiny:
		unit.final_destiny = Vector2.ZERO
	unit.current_destiny = Vector2.ZERO
	unit.set_state("idle")
	unit.get_node("animations").speed_scale = 1
	if unit.collision_timer and unit.collision_timer.time_left > 0: 
		unit.collision_timer.stop() # first stops previous timers


func stand(unit):
	unit.current_path = []
	stop(unit)



func smart(unit, target_point):
	if not unit.agent.get_state("stunned"):
		var path = Behavior.path.find(unit.global_position, target_point)
		if path: Behavior.path.start(unit, path)



func teleport(unit, target_point):
	var agent = unit.agent
	var game = get_tree().get_current_scene()
	var ui = game.ui
	ui.unit_controls_panel.teleport_button.disabled = false
	ui.unit_controls_panel.teleport_button.button_pressed = false
	var building = Utils.closer_building(target_point, unit.team)
	var distance = building.global_position.distance_to(target_point)
	Behavior.move.stop(unit)
	agent.set_state("is_channeling", true)
	# todo move to timer
	await get_tree().create_timer(teleport_time).timeout
	if agent.get_state("is_channeling"):
		agent.set_state("has_player_command", false)
		agent.set_state("is_channeling", false)
		var new_position = target_point
		# prevent teleport into buildings
		var min_distance = 2 * building.collision_radius + unit.collision_radius
		if distance <= min_distance:
			var offset = (target_point - building.global_position).normalized()
			new_position = building.global_position + (offset * min_distance)
		# limit teleport range
		if distance > teleport_max_distance:
			var offset = (target_point - building.global_position).normalized()
			new_position = building.global_position + (offset * teleport_max_distance)

		unit.global_position = new_position
		# emit signal teleported
		agent.set_state("lane", building.lane)
		Behavior.path.resume_lane(unit)
