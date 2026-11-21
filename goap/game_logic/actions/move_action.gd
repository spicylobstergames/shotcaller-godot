# =============================================================================
# GOAP-GUIDE: Move - action (goap/game_logic/actions/move_action.gd)
# =============================================================================
# Purpose   : Hand unit.current_destiny to the movement driver. The actual
#             stepping happens in Collisions.physics_process for units whose
#             unit.state == "move".
# Plannable : yes - the movement step of most plans.
# is_valid  : unit.moves
# precond   : {"has_destiny": true, "is_stunned": false}
# effects   : {"arrived_at_destination": true, "lane_route_finished": true}
# enter     : move(unit, unit.current_destiny).
# perform   : always true -- a one-shot plan step. The step itself is driven
#             by Collisions for state == "move" units. Returning false after
#             arrival (PR #233) parked the plan forever and froze arrived
#             units: the agent only replans when the goal CHANGES.
# Helpers   : point / in_bounds / move / calc_step / step / _resolve_blocking /
#             resume / stop / teleport.
# Writes    : unit.current_destiny, current_step, angle, state via unit.set_state.
# Traps     : stop() zeroes current_destiny and final_destiny; a zeroed destiny
#             that reaches move() walks the unit toward the map origin.
# See       : tests/unit/test_movement.gd.
# =============================================================================

extends "res://goap/goap_system/action_contract.gd"

const teleport_time = 3
const teleport_max_distance = 100


func get_class_name() -> String:
	return "Move"


func is_valid(agent) -> bool:
	var unit = agent.get_unit()
	return unit.moves


#func get_cost(_agent) -> int:
#	return 1


func get_preconditions() -> Dictionary:
	return {
		"has_destiny": true,
		"is_stunned": false
	}


func get_effects() -> Dictionary:
	return {
		"arrived_at_destination": true,
		"lane_route_finished": true
	}


func perform(agent, _delta) -> bool:
	# Always complete: the step itself is driven by Collisions for units whose
	# state == "move", and the agent only replans when the goal CHANGES. PR #233
	# (73f69c0) made this return false once arrived_at_destination was set,
	# which parks the plan forever — an arrived unit sat on a dead [Move] plan
	# with its goal frozen ("fights, kills, then stands still"). The original
	# contract was "the step is done, advance me" (it returned true always).
	# Regression: tests/unit/test_movement.gd ("Move.perform completes after
	# arrival"), and ARCHITECTURE.md "State facts".
	return true


func enter(agent):
	var unit = agent.get_unit()
	move(unit, unit.current_destiny)


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
		# History sub-event (best effort: test doubles may not carry the
		# record API). Nothing in planning reads the history.
		if unit.agent != null and unit.agent.has_method("record_event"):
			unit.agent.record_event("move_request", destiny)
		# Any newly issued movement revokes a previous arrival: the fact
		# must read false until Collisions detects the NEXT arrival, or a
		# plan action could mistake an old arrival for its own.
		unit.agent.set_state("arrived_at_destination", false)
		unit.current_destiny = destiny
		var current_speed = max(Modifiers.get_value(unit, "speed"), 0.0)
		calc_step(unit, current_speed)
		unit.set_state("move")


func calc_step(unit, speed):
	var distance = unit.current_destiny - unit.global_position
	if speed > 0 and distance.length_squared() > 0:
		unit.angle = distance.angle()
		unit.current_step = distance.normalized() * speed
		unit.mirror_look_at(unit.current_destiny)
	else:
		unit.current_step = Vector2.ZERO
	var animations: AnimationPlayer = unit.animations
	if animations:
		animations.speed_scale = speed / max(unit.speed, 0.0001)



func step(unit, delta): 
	if delta <= 0: return
	calc_step(unit, max(Modifiers.get_value(unit, "speed"), 0.0))
	var motion = unit.current_step * delta
	var speed2 = motion.length_squared()
	var distance_to_destination = unit.current_destiny - unit.global_position
	# if too fast check if won't move after destiny
	if speed2 > distance_to_destination.length_squared():
		motion = distance_to_destination
	motion = _resolve_blocking(unit, motion)
	unit.global_position += motion


func _resolve_blocking(unit, motion: Vector2) -> Vector2:
	var resolved_motion = motion
	var destination = unit.global_position + unit.collision_position + motion
	var units_at_destination = Collisions.get_units_in_radius(destination, unit.collision_radius)
	
	for other in units_at_destination:
		var other_unit_collides = (other != unit) and other.collide and !other.dead
		if other_unit_collides:
			var other_position = other.global_position + other.collision_position
			var minimum_distance = unit.collision_radius + other.collision_radius
			if destination.distance_to(other_position) < minimum_distance:
				var diff = destination - other_position
				resolved_motion += diff * 0.05 # small reppelling force 

	# Forward-progress floor: in a dense crowd the accumulated repulsion can
	# cancel (even reverse) the step, and packed units then jitter in place at
	# lane choke points forever. Repulsion is meant to soften overlaps, not to
	# stop movement, so never let it remove more than 40% of the intended step
	# along the original direction. Sideways deflection is preserved.
	# Regression: tests/unit/test_movement.gd ("crowded unit still advances").
	if motion.length_squared() > 0.0:
		var forward := motion.normalized()
		var along: float = resolved_motion.dot(forward)
		var minimum := motion.length() * 0.6
		if along < minimum:
			resolved_motion += forward * (minimum - along)

	return resolved_motion


func resume(unit):
	if not unit.agent.get_state("is_stunned"):
		move(unit, unit.current_destiny)


func stop(unit):
	unit.current_step = Vector2.ZERO
	unit.current_destiny = Vector2.ZERO
	unit.final_destiny = Vector2.ZERO
	unit.set_state("idle")
	# Movement is over: drop the routing fact so the planner cannot satisfy
	# Move without a fresh Navigate. (has_destiny used to be never cleared --
	# the documented stale-fact trap that let plans skip Navigate.)
	if unit.agent != null:
		unit.agent.set_state("has_destiny", false)
	var animations: AnimationPlayer = unit.animations
	if animations:
		animations.speed_scale = 1.0


func teleport(unit, target_point):
	var agent = unit.agent
	var game = Goap.get_tree().get_current_scene()
	var ui = game.ui
	ui.unit_control_panel.teleport_button.disabled = false
	ui.unit_control_panel.teleport_button.button_pressed = false
	var building = Utils.closer_building(target_point, unit.team)
	var distance = building.global_position.distance_to(target_point)
	Goap.get_action("Move").stop(unit)
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
		agent.set_state("lane_route_finished", false)
		agent.erase_state("lane_resume_path")
		agent.set_state("resume_path", false)
		unit.current_path.clear()
		agent.get_goal("WalkLane").resume_lane(unit)
