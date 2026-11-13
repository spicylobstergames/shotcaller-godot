extends RefCounted

# PORT (post-restructure): the use_native_movement/use_native_blocking/
# use_native_pathfinding switches were removed — movement is one path now:
# move_action.step() advances toward current_destiny by Modifiers speed x
# delta (clamped at the destination) and blocking is a SOFT repulsion force
# (Collisions.get_units_in_radius), not a hard stop. The assertions test
# the current single path.

const MoveAction = preload("res://goap/game_logic/actions/move_action.gd")
const Quadtree = preload("res://collision/quadtree.gd")


# These doubles expose only what MoveAction.step/move need; no physics scene is required.
class TestAgent:
	extends RefCounted
	var state := {"is_stunned": false}

	func get_state(state_name: String, default_value = null):
		return state.get(state_name, default_value)

	func set_state(state_name: String, value) -> void:
		state[state_name] = value


class TestUnit:
	extends Node2D
	var moves := true
	var speed := 10.0
	var level := 1
	var current_step := Vector2.ZERO
	var current_destiny := Vector2.ZERO
	var collision_position := Vector2.ZERO
	var collision_radius := 8.0
	var collide := false
	var dead := false
	var angle := 0.0
	var animations = null  # calc_step reads unit.animations unconditionally
	var current_modifiers := {
		"hp": [], "regen": [], "vision": [], "speed": [], "damage": [],
		"attack_range": [], "attack_speed": [], "defense": [], "dot": []
	}
	var agent = TestAgent.new()

	# Stubs for the unit methods MoveAction touches.
	func mirror_look_at(_target) -> void:
		pass

	func set_state(_s) -> void:
		pass


func run(harness) -> void:
	# Actions are instance-based (Node-derived): exercise the registry's
	# shared instance, exactly like production does.
	var move_action = Goap.get_action("Move")
	# Restore the shared quadtree after testing.
	var old_quadtree = Collisions.quad
	# _resolve_blocking queries the live quadtree on every step.
	Collisions.quad = Quadtree.new(Collisions, Rect2(Vector2.ZERO, Vector2(256, 256)), 16, 4)
	var unit = TestUnit.new()
	unit.global_position = Vector2(32, 32)
	unit.current_destiny = Vector2(100, 32)

	# --- step advances toward the destiny by speed x delta ---
	move_action.step(unit, 1.0)
	harness.check_equal(
		unit.global_position,
		Vector2(42, 32),
		"Step advances units toward the destiny by speed x delta."
	)

	# --- step clamps at the destination (no overshoot) ---
	unit.current_destiny = Vector2(45, 32)
	move_action.step(unit, 1.0)
	harness.check_equal(
		unit.global_position,
		Vector2(45, 32),
		"Step clamps movement at the destination instead of overshooting."
	)

	# --- move() respects the moves flag and the stun state ---
	unit.moves = false
	move_action.move(unit, Vector2(200, 32))
	harness.check_equal(
		unit.current_destiny,
		Vector2(45, 32),
		"move() ignores the destiny when the unit cannot move."
	)
	unit.moves = true
	unit.agent.set_state("is_stunned", true)
	move_action.move(unit, Vector2(200, 32))
	harness.check_equal(
		unit.current_destiny,
		Vector2(45, 32),
		"move() ignores the destiny while the unit is stunned."
	)
	unit.agent.set_state("is_stunned", false)
	move_action.move(unit, Vector2(200, 32))
	harness.check_equal(
		unit.current_destiny,
		Vector2(200, 32),
		"move() accepts a new destiny for a healthy moving unit."
	)

	# --- soft blocking: a colliding unit repels motion toward it ---
	# Baseline first, with an EMPTY quadtree, so the unobstructed step cannot
	# be influenced by the test unit or blocker sitting in the tree.
	var unblocked_unit = TestUnit.new()
	unblocked_unit.global_position = Vector2(100, 32)
	unblocked_unit.current_destiny = Vector2(200, 32)
	move_action.step(unblocked_unit, 1.0)
	var free_pos_x = unblocked_unit.global_position.x

	var blocker = TestUnit.new()
	blocker.collide = true
	# Inside the combined collision radius (8 + 8) of the unit's next position.
	blocker.global_position = Vector2(115, 32)
	Collisions.quad.add_body(unit)
	Collisions.quad.add_body(blocker)
	unit.global_position = Vector2(100, 32)
	unit.current_destiny = Vector2(200, 32)
	move_action.step(unit, 1.0)
	harness.check(
		unit.global_position.x < free_pos_x,
		"A colliding blocker repels motion toward it (soft blocking reduces progress)."
	)
	# The unit still makes progress (soft, not hard blocked).
	harness.check(
		unit.global_position.x > 100.0,
		"Soft blocking does not hard-stop movement."
	)

	harness.check(
		Goap.get_action("Move") != null,
		"Move action is registered with the GOAP action registry."
	)

	unit.free()
	blocker.free()
	unblocked_unit.free()
	Collisions.quad = old_quadtree
