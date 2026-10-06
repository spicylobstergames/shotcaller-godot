extends Node


# self = Goap.movement

const teleport_time = 3
const teleport_max_distance = 100


func setup_timer(unit):
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
		var current_speed = Goap.modifiers.get_value(unit, "speed")
		calc_step(unit, current_speed)
		# todo fix instantiated scene call
		unit.get_node("animations").speed_scale = current_speed / unit.speed
		unit.set_state("move")



func calc_step(unit, speed):
	if speed > 0:
		var distance = unit.current_destiny - unit.global_position
		unit.angle = distance.angle()
		unit.current_step = Vector2(speed* cos(unit.angle), speed * sin(unit.angle))
		unit.mirror_look_at(unit.current_destiny)



func step(unit, delta):
	var velocity = unit.current_step
	if unit.advance_with_navigation(delta):
		velocity = unit.current_step
	if unit is CharacterBody2D:
		unit.velocity = velocity
		unit.move_and_slide()
	else:
		unit.global_position += velocity * delta


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
	# todo fix instantiated scene call
	unit.get_node("animations").speed_scale = 1


func smart(unit, target_point):
	if not unit.agent.get_state("stunned"):
		Goap.navigation.navigate_to(unit, target_point)
	# todo add queue to resume movement


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
	# todo move to world state timer
	await get_tree().create_timer(teleport_time).timeout
	if (
		agent.get_state("is_channeling")
		and agent.get_state("player_order_id", 0) == order_id
	):
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
		Goap.get_action("OrderAction").complete_player_order(agent)
		Goap.navigation.resume_lane(unit)
