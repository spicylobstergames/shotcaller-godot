extends RefCounted

# PORT (post-restructure): the lane/leader priority system
# (build_lane_priorities, set_lane_priority, target_priority agent state)
# was REMOVED — ChooseTarget.select_target is now proximity-based with
# can_hit filtering. This suite pins the current targeting contract.

const ChooseTarget = preload("res://goap/game_logic/actions/choose_target.gd")


class TestUnit:
	extends Node2D
	var team := "blue"
	var type := "pawn"
	var dead := false
	var immune := false
	var moves := true
	var attack_range := 100.0
	var attack_hit_radius := 1.0  # get_att_range = attack_hit_radius * attack_range
	var collision_radius := 8.0
	var attack_hit_position := Vector2.ZERO
	var collision_position := Vector2.ZERO
	var level := 1
	var current_modifiers := {
		"hp": [], "regen": [], "vision": [], "speed": [], "damage": [],
		"attack_range": [], "attack_speed": [], "defense": [], "dot": []
	}

	# Minimal distance-sort stub (the real Unit method): returns
	# [{unit, distance}] sorted by distance, as select_target expects.
	func sort_by_distance(units: Array) -> Array:
		var entries := []
		for u in units:
			entries.append({"unit": u, "distance": global_position.distance_to(u.global_position)})
		entries.sort_custom(func(a, b): return a.distance < b.distance)
		return entries


func run(harness) -> void:
	var action = ChooseTarget.new()

	# --- can_hit: the targeting filter ---
	var unit = TestUnit.new()
	unit.global_position = Vector2(100, 100)

	var enemy = TestUnit.new()
	enemy.team = "red"
	enemy.global_position = Vector2(200, 100)

	harness.check(action.can_hit(unit, enemy), "A live enemy of another team is a valid target.")
	harness.check(not action.can_hit(unit, unit), "A unit never targets itself.")
	var friend = TestUnit.new()
	friend.team = "blue"
	harness.check(not action.can_hit(unit, friend), "A same-team unit is never a target.")
	var corpse = TestUnit.new()
	corpse.team = "red"
	corpse.dead = true
	harness.check(not action.can_hit(unit, corpse), "A dead unit is never a target.")
	var block = TestUnit.new()
	block.team = "red"
	block.type = "block"
	harness.check(not action.can_hit(unit, block), "Terrain blocks are never targets.")
	var immune_unit = TestUnit.new()
	immune_unit.team = "red"
	immune_unit.immune = true
	harness.check(not action.can_hit(unit, immune_unit), "An immune unit is never a target.")

	# --- select_target: filtering + proximity ---
	harness.check_equal(
		action.select_target(unit, []), null,
		"No enemies means no target."
	)
	harness.check_equal(
		action.select_target(unit, [enemy]), enemy,
		"A single valid enemy is selected outright."
	)

	var far_enemy = TestUnit.new()
	far_enemy.team = "red"
	far_enemy.global_position = Vector2(500, 100)
	harness.check_equal(
		action.select_target(unit, [far_enemy, enemy]), enemy,
		"The closest valid enemy wins."
	)

	# Dead enemies are filtered out even when closer.
	corpse.global_position = Vector2(120, 100)
	harness.check_equal(
		action.select_target(unit, [corpse, enemy]), enemy,
		"A closer dead enemy is filtered; the live one is selected."
	)

	# --- in_range / is_valid_target ---
	harness.check(action.in_range(unit, enemy),
		"An enemy inside attack_range is in range (100 range vs 100 distance, radii included).")
	harness.check(not action.in_range(unit, far_enemy),
		"An enemy beyond attack_range is out of range.")
	harness.check(action.is_valid_target(unit, enemy),
		"can_hit + in_range agree for a valid reachable enemy.")
	harness.check(not action.is_valid_target(unit, far_enemy),
		"A valid but unreachable enemy fails is_valid_target.")
