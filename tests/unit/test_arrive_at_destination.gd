extends RefCounted

# PORT (post-restructure): the arrival goal's is_valid() now hard-returns
# false (activation logic commented out in production) — arrival is handled
# by Collisions calling is_at_destination/on_arrive directly. This test PINS
# that contract: goal selection never activates it, its state management
# (enter/on_arrive) still works when invoked directly, and the collision
# callback keeps using the map tolerance for autonomous movement. If the
# commented-out activation logic is ever restored, this test must be
# deliberately flipped.

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
	var animations = null  # MoveAction.stop reads unit.animations
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
	var ws = preload("res://tests/helpers/world_state_snapshot.gd").new()
	ws.set_state("map", TestMap.new())
	var goal = ArriveAtDestination.new()
	var unit = TestUnit.new()
	var agent = TestAgent.new(unit)

	# PINNED (see file header): the goal never self-activates — regardless of
	# unit state. Arrival is driven by Collisions calling is_at_destination /
	# on_arrive directly.
	unit.state = "move"
	unit.current_destiny = Vector2(100, 50)
	harness.check(not goal.is_valid(agent),
		"PINNED: the arrival goal does not self-activate (activation disabled; arrival is collision-driven).")
	unit.current_path = [Vector2(150, 50)]
	harness.check(not goal.is_valid(agent),
		"PINNED: a queued path does not self-activate the arrival goal either.")

	# enter() state management still works when invoked (the goal stays in
	# agents' goals_list, and Recover chains into it via on_arrive).
	goal.enter(agent)
	harness.check_equal(agent.get_state("has_path"), true, "enter() reflects the queued path in state.")
	harness.check_equal(
		agent.get_state("arrived_at_destination"),
		false,
		"enter() clears the arrived state."
	)

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

	# Explicit player destinations should not use the wider autonomous-lane tolerance.
	unit.target = TestUnit.new()
	goal.is_at_destination(unit)
	harness.check_equal(
		unit.last_collision_offset, 0, "Player movement uses an exact destination check."
	)
	unit.target = null

	# Finishing the last waypoint clears planner state and stops direct movement.
	# on_arrive takes the UNIT — that is how collisions.gd invokes it.
	goal.on_arrive(unit)
	harness.check_equal(agent.get_state("has_path"), false, "Completing a path clears path state.")
	harness.check_equal(
		agent.get_state("arrived_at_destination"), true, "Completing a path sets the arrived state."
	)
	harness.check_equal(unit.state, "idle", "Completing a path stops the unit.")
	unit.free()
	ws.restore()
