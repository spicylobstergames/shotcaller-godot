extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func setup_timer(unit):
	unit.collision_timer = Timer.new()
	unit.collision_timer.one_shot = true
	unit.add_child(unit.collision_timer)


func start(unit, destiny):
	if unit.moves:
		unit.set_behavior("move")
		move(unit, destiny)


func in_bounds(p):
	var l = 32
	return p.x > l and p.y > l and p.x < game.size - l and p.y < game.size - l


func move(unit, destiny):
	if unit.moves and in_bounds(destiny):
		#if !unit.lane:
		#	unit.path = game.map.find_path(unit.global_position, destiny)
		unit.current_destiny = destiny
		calc_step(unit)
		unit.set_state("move")


func calc_step(unit):
	if unit.current_speed > 0:
		var distance = unit.current_destiny - unit.global_position
		unit.angle = distance.angle()
		unit.current_step = Vector2(unit.current_speed * cos(unit.angle), unit.current_speed * sin(unit.angle))
		unit.look_at(unit.current_destiny)


func step(unit):
	unit.global_position += unit.current_step


func on_collision(unit):
	var target = unit.collide_target
	if target and target != unit.target:
		var nd # new direction
		var a1 = unit.angle
		var p1 = unit.global_position + unit.collision_position
		var p2 = target.global_position + target.collision_position
		var pr = p2 - p1 # relative position
		var a2 = pr.angle() # angle between units
		var rda = game.utils.limit_angle(a1 - a2) # angle relative to new direction
		# new direction: rotates pr +-90 deg (tangent direction)
		if (rda > 0): nd = Vector2(-pr.y, pr.x)
		else: nd = Vector2(pr.y, -pr.x)
		var da = nd.angle()
		if unit.global_position == unit.last_position2: 
				# force back move to unstuck
			unit.global_position -= pr.normalized()
			da = -PI + (randf()*2*PI) # and try random direction
		# change directioin
		unit.angle = da
		unit.current_step = Vector2(unit.current_speed * cos(unit.angle), unit.current_speed * sin(unit.angle))
		# send back to original destiny after some time
		if unit.collision_timer.time_left > 0: 
			unit.collision_timer.stop() # stops previous timers
		# time inverse proportional to speed
		unit.collision_timer.wait_time = (0.2 + (randf() * 0.4)) / unit.current_speed
		unit.collision_timer.start()
		yield(unit.collision_timer, "timeout")
		move(unit, unit.current_destiny)


func resume(unit):
	if unit.behavior == "move":
		move(unit, unit.current_destiny)


func end(unit):
	if unit.behavior == "move": 
		stop(unit)
		unit.set_behavior("stand")


func stop(unit):
	unit.current_step = Vector2.ZERO
	unit.current_destiny = Vector2.ZERO
	unit.set_state("idle")

