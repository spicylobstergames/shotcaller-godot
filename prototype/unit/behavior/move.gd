extends Node

var game:Node


# self = Behavior.move


func _ready():
	game = get_tree().get_current_scene()


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
	var l = game.map.tile_size / 2
	return p.x > l and p.y > l and p.x < game.map.size - l and p.y < game.map.size - l



func move(unit, destiny):
	if (
		unit.moves
		and not unit.agent.get_state("is_stunned")
		and not unit.agent.get_state("command_casting")
	):
		unit.current_destiny = destiny
		var current_speed = Behavior.modifiers.get_value(unit, "speed")
		calc_step(unit, current_speed)
		unit.get_node("animations").playback_speed = current_speed / unit.speed
		unit.set_state("move")



func calc_step(unit, speed):
	if speed > 0:
		var distance = unit.current_destiny - unit.global_position
		unit.angle = distance.angle()
		unit.current_step = Vector2(speed* cos(unit.angle), speed * sin(unit.angle))
		unit.look_at(unit.current_destiny)



func step(unit, delta):	
	unit.global_position += unit.current_step * delta


func on_collision(unit, delta):
	var target = unit.collide_target
	if target and target != unit.target:
		var a # new direction
		var p1 = unit.global_position + unit.collision_position
		var p2 = target.global_position + target.collision_position
		var pr = p2 - p1 # relative target position
		var ang_to_target = pr.angle() # target relative angle
		# angle between direction and target
		var rda = game.utils.limit_angle(unit.angle - ang_to_target) 
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
		unit.collision_timer.wait_time = 0.1 + randf() * 0.2
		unit.collision_timer.start()
		
		yield(unit.collision_timer, "timeout")
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
	unit.current_destiny = Vector2.ZERO
	unit.set_state("idle")
	unit.get_node("animations").playback_speed = 1
	if unit.collision_timer and unit.collision_timer.time_left > 0: 
		unit.collision_timer.stop() # first stops previous timers


func stand(unit):
	var agent = unit.agent
	agent.set_state("current_path", [])
	stop(unit)



func smart(unit, point, cb):
	if not unit.agent.get_state("stunned") and not unit.agent.get_state("command_casting"):
		var path = Behavior.follow.find_path(unit.global_position, point)
		if path: Behavior.follow.path(unit, path, cb)

