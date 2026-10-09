extends RefCounted

const MoveAction = preload("res://goap/game_logic/actions/move_action.gd")
const Quadtree = preload("res://collision/quadtree.gd")


# These doubles expose only what MoveAction.step needs; no physics scene is required.
class TestAgent:
	extends RefCounted
	var state := {}

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)


class TestUnit:
	extends Node2D
	var moves := true
	var current_step := Vector2.ZERO
	var collision_position := Vector2.ZERO
	var collision_radius := 8.0
	var collide := false
	var dead := false
	var agent = TestAgent.new()

	func advance_with_navigation(_delta: float) -> bool:
		return false


func run(harness) -> void:
	# Restore singleton switches and the shared quadtree after testing each backend.
	var old_native_movement = Goap.use_native_movement
	var old_native_blocking = Goap.use_native_blocking
	var old_native_pathfinding = Goap.use_native_pathfinding
	var old_quadtree = Collisions.quad
	var unit = TestUnit.new()
	unit.global_position = Vector2(32, 32)
	unit.current_step = Vector2(10, 0)

	# Keep native path-following disabled here so this isolates physics-body movement.
	Goap.use_native_movement = true
	Goap.use_native_blocking = true
	Goap.use_native_pathfinding = false
	Goap.get_action("MoveAction").step(unit, 1.0)
	harness.check_equal(
		unit.global_position,
		Vector2(42, 32),
		"Native movement advances units by velocity and delta."
	)

	Goap.use_native_movement = false
	Goap.use_native_blocking = true
	Goap.get_action("MoveAction").step(unit, 1.0)
	harness.check_equal(
		unit.global_position,
		Vector2(52, 32),
		"Legacy movement advances without relying on native movement."
	)

	var blocker = TestUnit.new()
	blocker.collide = true
	blocker.global_position = Vector2(66, 32)
	Collisions.max_collision_radius = blocker.collision_radius
	Collisions.quad = Quadtree.new(Collisions, Rect2(Vector2.ZERO, Vector2(256, 256)), 16, 4)
	Collisions.quad.add_body(unit)
	Collisions.quad.add_body(blocker)
	Goap.use_native_blocking = false
	# The blocker stays indexed in the quadtree; radius filtering uses its updated position.
	Goap.get_action("MoveAction").step(unit, 1.0)
	harness.check_equal(
		unit.global_position,
		Vector2(52, 32),
		"Legacy quadtree blocking prevents movement into another unit."
	)

	blocker.global_position = Vector2(220, 220)
	Goap.get_action("MoveAction").step(unit, 1.0)
	harness.check_equal(
		unit.global_position,
		Vector2(62, 32),
		"Legacy quadtree blocking permits unobstructed movement."
	)
	harness.check(
		Goap.get_action("MoveAction") != null,
		"MoveAction is registered with the GOAP action registry."
	)

	unit.free()
	blocker.free()
	Collisions.quad = old_quadtree
	Goap.use_native_movement = old_native_movement
	Goap.use_native_blocking = old_native_blocking
	Goap.use_native_pathfinding = old_native_pathfinding
