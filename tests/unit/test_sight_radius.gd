extends RefCounted

# Regression suite for phantom sight.
#
# Quadtree._get_bodies_in_radius has no per-body distance test in leaf cells:
# any quadrant the query circle merely overlaps contributes ALL of its bodies.
# Unit.get_units_in_sight treated that result as authoritative, so units
# "saw" enemies far outside vision (live-measured: an enemy 735px away with
# vision=140). Consequences: EnemyDefeated stayed valid with nothing near,
# and moving units locked onto unreachable phantoms after a kill and stood
# stuck chasing them. get_units_in_sight now enforces the real vision radius.
#
# (Raw radius queries keep their coarse semantics by design — every other
# consumer, from cleave to pierce to soft-repulsion, re-checks real distance
# on the candidates it gets.)

const Quadtree = preload("res://collision/quadtree.gd")
const UnitScript = preload("res://unit/Unit.gd")


class FakeMap:
	extends Node2D
	var tile_size := 64
	var half_tile_size := 32
	var size := Vector2(2048, 2048)


func run(harness) -> void:
	var saved_quad = Collisions.quad
	var saved_tile = Collisions.tile_size
	var saved_half = Collisions.half_tile_size
	var saved_map = Collisions.current_map

	Collisions.setup_quadtree(FakeMap.new())

	var viewer = UnitScript.new()
	viewer.team = "blue"
	viewer.vision = 140
	viewer.global_position = Vector2(600, 600)

	var near_enemy = UnitScript.new()
	near_enemy.team = "red"
	near_enemy.global_position = Vector2(680, 600)  # 80px — inside vision

	var far_enemy = UnitScript.new()
	far_enemy.team = "red"
	far_enemy.global_position = Vector2(80, 80)  # ~735px — far outside vision

	var far_friend = UnitScript.new()
	far_friend.team = "blue"
	far_friend.global_position = Vector2(640, 720)  # ~123px — inside vision

	var dead_enemy = UnitScript.new()
	dead_enemy.team = "red"
	dead_enemy.dead = true
	dead_enemy.global_position = Vector2(620, 600)  # inside vision, but dead

	for body in [viewer, near_enemy, far_enemy, far_friend, dead_enemy]:
		Collisions.quad.add_body(body)

	var sight = viewer.get_units_in_sight({"team": viewer.opponent_team()})
	var sight_names := []
	for u in sight:
		sight_names.append(u.team)

	harness.check_equal(sight.size(), 1,
		"Sight returns only units within vision (was: every body in overlapping quadrants).")
	harness.check(sight.size() == 1 and sight[0] == near_enemy,
		"Sight returns the in-range enemy, not the phantom 735px away.")
	harness.check(not sight_names.has("blue"),
		"Sight team filter still applies (no friends in enemy sight).")

	var allies = viewer.get_units_in_sight({"team": viewer.team})
	harness.check_equal(allies.size(), 1,
		"Ally sight is distance-filtered too (the far friend is beyond vision).")

	# A big query still reaches far units: vision semantics, not a hard cap
	# on the query system itself.
	var wide = viewer.get_units_in_radius(1000, {"team": "red"})
	harness.check(wide.size() >= 1,
		"Raw radius queries still work (unfiltered, as their consumers expect).")

	viewer.free()
	near_enemy.free()
	far_enemy.free()
	far_friend.free()
	dead_enemy.free()

	Collisions.quad = saved_quad
	Collisions.tile_size = saved_tile
	Collisions.half_tile_size = saved_half
	Collisions.current_map = saved_map
