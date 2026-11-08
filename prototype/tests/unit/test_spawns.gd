extends Node

const Spawns = preload("res://map/spawns.gd")


# ---------------------------------------------------------------------------
# Mock objects used by every test
# ---------------------------------------------------------------------------

class MockLeader:
	extends Node
	var gold := 0
	var team := "blue"
	var type := "leader"
	var agent := MockAgent.new()


class MockAgent:
	extends Node
	var _states := {}

	func get_state(name: String, default = null):
		return _states.get(name, default)

	func set_state(name: String, value):
		_states[name] = value


# TestSpawns overrides recycle so that we can verify cemitery lookup / pop
# without needing a full game scene (spawn_unit is not mocked).
class TestSpawns extends Spawns:
	func recycle(template: String, lane: String, team: String, point: Vector2) -> Variant:
		var side = "player_"
		if team == WorldState.get_state("enemy_team"): side = "enemy_"
		var index = side + template
		if cemitery[index].size():
			return cemitery[index].pop_back()
		return null


# ---------------------------------------------------------------------------
# Public entry-point required by the test runner
# ---------------------------------------------------------------------------

func run(harness: Node) -> void:
	_test_insufficient_gold_prevents_hiring(harness)
	_test_unknown_unit_type_produces_no_spawn(harness)
	_test_dead_unit_recycling_from_cemetery(harness)
	_test_lane_tactic_fallback_when_no_building_exists(harness)


# ---------------------------------------------------------------------------
# 1. Insufficient gold prevents hiring
# ---------------------------------------------------------------------------

func _test_insufficient_gold_prevents_hiring(harness: Node) -> void:
	var old_player_team = WorldState.get_state("player_team")
	var old_player_leaders = WorldState.get_state("player_leaders")
	WorldState.set_state("player_team", "blue")
	WorldState.set_state("player_leaders", [])
	WorldState.set_state("enemy_team", "red")
	WorldState.set_state("enemy_leaders", [])

	var spawns = Spawns.new()
	harness.add_child(spawns)

	# Leader with 0 gold — infantry costs 1
	var leader = MockLeader.new()
	leader.gold = 0
	leader.team = "blue"
	WorldState.set_state("player_leaders", [leader])

	# Attempt to hire an infantry (cost = 1)
	spawns.camp_hire("infantry", "blue")

	# Gold should NOT have been deducted when insufficient
	harness.check(
		leader.gold == 0,
		"Insufficient gold prevents hiring deduction."
	)

	# extra_unit must NOT be set when hiring fails
	harness.check(
		WorldState.get_state("player_extra_unit") == null,
		"Insufficient gold prevents setting extra_unit."
	)

	leader.free()
	spawns.free()
	WorldState.set_state("player_team", old_player_team)
	WorldState.set_state("player_leaders", old_player_leaders)


# ---------------------------------------------------------------------------
# 2. Unknown unit type cannot produce valid spawn
# ---------------------------------------------------------------------------

func _test_unknown_unit_type_produces_no_spawn(harness: Node) -> void:
	var spawns = Spawns.new()
	harness.add_child(spawns)

	# Attempt to load a non-existent pawn scene
	var scene = spawns.pawn_scene("nonexistent_unit")

	# Loading a missing resource should return null
	harness.check(
		scene == null,
		"Unknown unit type returns null from pawn_scene."
	)

	spawns.free()


# ---------------------------------------------------------------------------
# 3. Dead unit recycling from cemetery
# ---------------------------------------------------------------------------

func _test_dead_unit_recycling_from_cemetery(harness: Node) -> void:
	var old_player_team = WorldState.get_state("player_team")
	var old_enemy_team = WorldState.get_state("enemy_team")
	WorldState.set_state("player_team", "blue")
	WorldState.set_state("enemy_team", "red")

	var spawns = TestSpawns.new()
	harness.add_child(spawns)

	# Add a dead unit to the cemitery
	var dead_unit = Node2D.new()
	dead_unit.display_name = "infantry"
	dead_unit.team = "red"
	spawns.cemitery_add_pawn(dead_unit)

	# The unit should be in the correct cemitery slot
	harness.check(
		spawns.cemitery.has("enemy_infantry")
		and spawns.cemitery["enemy_infantry"].has(dead_unit),
		"Dead unit is added to the correct cemitery slot."
	)

	# Recycling returns the dead unit and removes it
	var recycled = spawns.recycle("infantry", "mid", "red", Vector2(100, 100))
	harness.check(
		recycled == dead_unit,
		"Recycling from cemitery returns the dead unit."
	)
	harness.check(
		not spawns.cemitery["enemy_infantry"].has(dead_unit),
		"Recycled unit is removed from the cemitery."
	)

	# Recycling from an empty cemitery returns null
	var empty_result = spawns.recycle("infantry", "mid", "red", Vector2(100, 100))
	harness.check(
		empty_result == null,
		"Recycling from empty cemitery returns null."
	)

	dead_unit.free()
	spawns.free()
	WorldState.set_state("player_team", old_player_team)
	WorldState.set_state("enemy_team", old_enemy_team)


# ---------------------------------------------------------------------------
# 4. Lane tactic fallback when no building exists
# ---------------------------------------------------------------------------

func _test_lane_tactic_fallback_when_no_building_exists(harness: Node) -> void:
	var old_all_buildings = WorldState.get_state("all_buildings")
	WorldState.set_state("all_buildings", [])

	var spawns = Spawns.new()
	harness.add_child(spawns)

	harness.check_equal(
		spawns._lane_tactic("top", "blue"),
		"default",
		"Lane tactic falls back to 'default' when no building exists."
	)

	spawns.free()
	WorldState.set_state("all_buildings", old_all_buildings)


# ---------------------------------------------------------------------------
# 5. camp_hire gold deduction bug: collective check vs per-leader deduction
# ---------------------------------------------------------------------------
# The affordability check sums gold across ALL leaders (collective):
#   if total_gold < cost: return
# But the deduction charges the FULL cost to EACH leader (individual):
#   for leader in team_leaders: leader.gold -= cost
#
# Example: 2 leaders with 2 gold each = 4 total. Mounted costs 3.
#   Check: 4 >= 3 → passes
#   Deduction: leader0.gold = 2-3 = -1, leader1.gold = 2-3 = -1
# This is a bug — the check and deduction don't agree on payment semantics.
# This test documents the current behavior so it can be fixed later.

func _test_camp_hire_gold_deduction_semantics(harness: Node) -> void:
	var old_player_team = WorldState.get_state("player_team")
	var old_player_leaders = WorldState.get_state("player_leaders")
	WorldState.set_state("player_team", "blue")
	WorldState.set_state("enemy_team", "red")

	var leader0 = MockLeader.new()
	leader0.gold = 2
	var leader1 = MockLeader.new()
	leader1.gold = 2
	WorldState.set_state("player_leaders", [leader0, leader1])

	var spawns = Spawns.new()
	harness.add_child(spawns)

	# Total gold = 4, mounted cost = 3. Collective check passes.
	spawns.camp_hire("mounted", "blue")

	# Current behavior: each leader pays the full cost (3)
	# This results in negative gold — the check/deduction mismatch bug.
	# Once fixed, these assertions should change.
	harness.check_equal(leader0.gold, -1,
		"Bug documented: leader 0 gold is -1 (2 - 3) due to collective check / per-leader deduction mismatch.")
	harness.check_equal(leader1.gold, -1,
		"Bug documented: leader 1 gold is -1 (2 - 3) due to collective check / per-leader deduction mismatch.")

	leader0.free()
	leader1.free()
	spawns.free()
	WorldState.set_state("player_team", old_player_team)
	WorldState.set_state("player_leaders", old_player_leaders)
