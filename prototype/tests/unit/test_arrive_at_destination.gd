extends RefCounted

const ArriveAtDestination = preload("res://goap/game_logic/goals/arrive_at_destination.gd")


# Minimal doubles isolate the goal from map loading, unit scenes, and animation nodes.
class TestMap:
	extends RefCounted
	var tile_size := 64
	var half_tile_size := 32
	var size := Vector2(512, 512)


class TestUnit:
	extends Node2D
	var moves := true
	var state := "idle"
	var current_step := Vector2.ZERO
	var current_destiny := Vector2.ZERO
	var final_destiny := Vector2.ZERO
	var current_path: Array = []
	var target: Node2D
	var agent
	var collision := false
	var last_collision_point := Vector2.ZERO
	var last_collision_offset := -1.0

	func point_collision(point: Vector2, offset := 0.0) -> bool:
		last_collision_point = point
		last_collision_offset = offset
		return collision

	func set_state(new_state: String) -> void:
		state = new_state


class TestAgent:
	extends RefCounted
	var unit
	var state := {}

	func _init(test_unit):
		unit = test_unit
		unit.agent = self

	func get_unit():
		return unit

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)

	func set_state(state_name: String, value) -> void:
		state[state_name] = value


func run(harness) -> void:
	# The arrival goal reads map sizing to choose its tolerance for lane movement.
	var old_map = WorldState.get_state("map")
	WorldState.set_state("map", TestMap.new())
	var goal = ArriveAtDestination.new()
	var unit = TestUnit.new()
	var agent = TestAgent.new(unit)

	harness.check(not goal.is_valid(agent), "Idle units do not activate the arrival goal.")
	unit.state = "move"
	unit.current_destiny = Vector2(100, 50)
	harness.check(goal.is_valid(agent), "Direct movement activates the arrival goal.")
	harness.check_equal(agent.get_state("has_path"), false, "Direct movement has no path.")
	harness.check_equal(
		agent.get_state("arrived_at_destination"),
		false,
		"Starting movement clears the arrived state."
	)

	unit.current_path = [Vector2(150, 50)]
	# Path state must activate the goal even while the unit is between waypoints.
	harness.check(goal.is_valid(agent), "A queued path activates the arrival goal.")
	harness.check_equal(agent.get_state("has_path"), true, "A queued path is reflected in state.")

	unit.current_path.clear()
	unit.collision = true
	harness.check(goal.is_at_destination(unit), "Destination collision is reported.")
	harness.check_equal(
		unit.last_collision_point, unit.current_destiny, "Arrival checks the active destination."
	)
	harness.check_equal(
		unit.last_collision_offset,
		WorldState.get_state("map").half_tile_size,
		"Uncommanded units use the lane arrival tolerance."
	)

	agent.set_state("has_player_command", true)
	goal.is_at_destination(unit)
	# Explicit player destinations should not use the wider autonomous-lane tolerance.
	harness.check_equal(
		unit.last_collision_offset, 0, "Player movement uses an exact destination check."
	)

	goal.on_arrive(agent)
	# Finishing the last waypoint should clear planner state and stop direct movement.
	harness.check_equal(agent.get_state("has_path"), false, "Completing a path clears path state.")
	harness.check_equal(
		agent.get_state("arrived_at_destination"), true, "Completing a path sets the arrived state."
	)
	harness.check_equal(unit.state, "idle", "Completing a path stops the unit.")
	unit.free()
	WorldState.set_state("map", old_map)
