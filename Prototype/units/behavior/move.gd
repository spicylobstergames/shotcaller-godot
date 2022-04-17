extends Node
var game:Node


const teleport_time = 3
const teleport_max_distance = 100

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
		unit.get_node("animations").playback_speed = unit.current_speed / unit.speed


func in_bounds(p):
	var l = 32
	return p.x > l and p.y > l and p.x < game.map.size - l and p.y < game.map.size - l



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
		var s = unit.current_speed
		unit.current_step = Vector2(s * cos(a), s * sin(a))
		# send back to original destiny after some time
		if unit.collision_timer.time_left > 0: 
			unit.collision_timer.stop() # first stops previous timers
		unit.collision_timer.wait_time = 0.1 + randf() * 0.2
		unit.collision_timer.start()
		yield(unit.collision_timer, "timeout")
		move(unit, unit.current_destiny)


func resume(unit):
	if unit.behavior == "move":
		move(unit, unit.current_destiny)


func end(unit):
	if unit.behavior == "move": 
		var retreat_end = game.unit.orders.retreat_end(unit)
		if not retreat_end: stand(unit)
		return retreat_end
	

func stop(unit):
	unit.current_step = Vector2.ZERO
	unit.current_destiny = Vector2.ZERO
	unit.set_state("idle")


func stand(unit):
	unit.current_path = []
	stop(unit)
	unit.set_behavior("stand")



func smart_move(unit, point):
	var path = game.unit.path.find_path(unit.global_position, point)
	if path: game.unit.path.follow(unit, path, "move")


func teleport(unit, point):
	game.ui.controls.teleport_button.disabled = true
	var building = game.utils.closer_building(point, unit.team)
	var distance = building.global_position.distance_to(point)
	game.control_state = "selection"
	game.ui.controls.teleport_button.disabled = false
	game.ui.controls.teleport_button.pressed = false
	game.unit.move.stand(unit)
	
	yield(get_tree().create_timer(teleport_time), "timeout")
	var new_position = point
	# prevent teleport into buildings
	var min_distance = 2 * building.collision_radius + unit.collision_radius
	if distance <= min_distance:
		var offset = (point - building.global_position).normalized()
		new_position = building.global_position + (offset * min_distance)
	# limit teleport range
	if distance > teleport_max_distance:
		var offset = (point - building.global_position).normalized()
		new_position = building.global_position + (offset * teleport_max_distance)

	unit.global_position = new_position
	follow_lane(unit)


func change_lane(unit, point):
	var lane = game.utils.closer_lane(point)
	unit.lane = lane
	follow_lane(unit)


func follow_lane(unit):
	var lane = unit.lane
	var path = game.map[lane].duplicate()
	if unit.team == "red": path.invert()
	game.unit.orders.setup_pawn(unit, lane)
	game.unit.path.follow(unit, path, "advance")
