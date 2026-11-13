extends Node

const Spawns = preload("res://map/spawns.gd")
const WorldStateSnapshot = preload("res://tests/helpers/world_state_snapshot.gd")


# ---------------------------------------------------------------------------
# Mock objects used by every test
# ---------------------------------------------------------------------------

class MockDeadPawn:
	extends Node2D
	var display_name := "infantry"
	var team := "red"


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


# Minimal hired-unit double: lumberjack_hire only calls setup_team + show
# when the mill already reports an existing lumberjack.
class MockHireUnit:
	extends RefCounted
	var team := ""
	var shown := false

	func setup_team(t):
		team = t

	func show():
		shown = true


class MockLumbermill:
	extends RefCounted
	var agent := MockAgent.new()
	var hired_unit

	func _init():
		hired_unit = MockHireUnit.new()
		agent.set_state("lumberjack", hired_unit)  # pre-seeded: skips creation

	func get_node_or_null(_path):
		return null


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
	_test_camp_hire_gold_deduction_semantics(harness)
	_test_camp_hire_leader_without_gold_property_does_not_crash(harness)
	_test_lumberjack_hire_has_no_affordability_gate(harness)


# ---------------------------------------------------------------------------
# 1. Insufficient gold prevents hiring
# ---------------------------------------------------------------------------

func _test_insufficient_gold_prevents_hiring(harness: Node) -> void:
	var ws = WorldStateSnapshot.new()
	ws.set_state("player_team", "blue")
	ws.set_state("player_leaders", [])
	ws.set_state("enemy_team", "red")
	ws.set_state("enemy_leaders", [])
	ws.set_state("player_extra_unit", null)

	var spawns = Spawns.new()
	harness.add_child(spawns)

	# Leader with 0 gold — infantry costs 1
	var leader = MockLeader.new()
	leader.gold = 0
	leader.team = "blue"
	ws.set_state("player_leaders", [leader])

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
	ws.restore()


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
	var ws = WorldStateSnapshot.new()
	ws.set_state("player_team", "blue")
	ws.set_state("enemy_team", "red")

	var spawns = TestSpawns.new()
	harness.add_child(spawns)

	# Add a dead unit to the cemitery
	var dead_unit = MockDeadPawn.new()
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
	ws.restore()


# ---------------------------------------------------------------------------
# 4. Lane tactic fallback when no building exists
# ---------------------------------------------------------------------------

func _test_lane_tactic_fallback_when_no_building_exists(harness: Node) -> void:
	var ws = WorldStateSnapshot.new()
	ws.set_state("all_buildings", [])

	var spawns = Spawns.new()
	harness.add_child(spawns)

	harness.check_equal(
		spawns._lane_tactic("top", "blue"),
		"default",
		"Lane tactic falls back to 'default' when no building exists."
	)

	spawns.free()
	ws.restore()


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
	# Regression test for the collective-check / individual-deduction mismatch.
	# Fixed semantics (matching lumberjack_hire): affordability is pooled team
	# gold, and the cost is SPLIT evenly across leaders.
	var ws = WorldStateSnapshot.new()
	ws.set_state("player_team", "blue")
	ws.set_state("enemy_team", "red")
	ws.set_state("player_extra_unit", null)

	var leader0 = MockLeader.new()
	leader0.gold = 2
	var leader1 = MockLeader.new()
	leader1.gold = 2
	ws.set_state("player_leaders", [leader0, leader1])

	var spawns = Spawns.new()
	harness.add_child(spawns)

	# Total gold = 4, mounted cost = 3. Collective check passes (4 >= 3).
	# Split payment: each leader pays floor(3 / 2) = 1 — nobody goes negative.
	spawns.camp_hire("mounted", "blue")

	harness.check_equal(leader0.gold, 1,
		"Camp hire splits cost: leader 0 pays floor(3/2)=1, ends at 1 gold (never negative).")
	harness.check_equal(leader1.gold, 1,
		"Camp hire splits cost: leader 1 pays floor(3/2)=1, ends at 1 gold (never negative).")
	harness.check_equal(WorldState.get_state("player_extra_unit"), "mounted",
		"Successful hire sets player_extra_unit.")

	leader0.free()
	leader1.free()
	spawns.free()
	ws.restore()


func _test_camp_hire_leader_without_gold_property_does_not_crash(harness: Node) -> void:
	# Regression: camp_hire used leader.get("gold", 0) (2-arg — invalid on
	# Node) and leader.gold -= cost (crashes if the property is absent).
	# A leader node WITHOUT a gold property must be skipped, not crash.
	var ws = WorldStateSnapshot.new()
	ws.set_state("player_team", "blue")
	ws.set_state("enemy_team", "red")
	ws.set_state("player_extra_unit", null)

	var rich = MockLeader.new()
	rich.gold = 10
	var no_gold = Node.new()  # plain Node: no "gold" property at all
	ws.set_state("player_leaders", [no_gold, rich])

	var spawns = Spawns.new()
	harness.add_child(spawns)

	# Pooled gold = 10 (only the leader with gold counts), infantry costs 1.
	# Must not crash on either the check or the deduction loop.
	spawns.camp_hire("infantry", "blue")

	# share = floor(1 / 2) = 0 — same floor-remainder behavior as
	# lumberjack_hire; the pooled check still gates the hire itself.
	harness.check_equal(rich.gold, 10,
		"Gold-less nodes are skipped in deduction; share floor(1/2)=0 so gold unchanged.")
	harness.check_equal(WorldState.get_state("player_extra_unit"), "infantry",
		"Hire succeeds when pooled gold covers the cost, ignoring gold-less nodes.")

	no_gold.free()
	rich.free()
	spawns.free()
	ws.restore()


# ---------------------------------------------------------------------------
# 7. lumberjack_hire has NO affordability gate (documented asymmetry)
# ---------------------------------------------------------------------------
# camp_hire pools team gold and refuses the hire when insufficient;
# lumberjack_hire does NOT check affordability at all — it deducts
# floor(cost / leaders) unconditionally and can drive leaders negative.
# ARCHITECTURE.md documents this asymmetry; this test pins it so a future
# "add the missing gate" fix flips this test deliberately.

func _test_lumberjack_hire_has_no_affordability_gate(harness: Node) -> void:
	var ws = WorldStateSnapshot.new()
	ws.set_state("player_team", "blue")
	ws.set_state("player_leaders", [])

	var leader = MockLeader.new()
	leader.gold = 0
	ws.set_state("player_leaders", [leader])

	var mill = MockLumbermill.new()
	var spawns = Spawns.new()
	harness.add_child(spawns)

	# lumberjack_cost is 1, one leader -> share 1. No gate: deduction happens
	# even though the leader cannot afford it.
	spawns.lumberjack_hire(mill, "blue")

	harness.check_equal(leader.gold, -1,
		"QUIRK: lumberjack_hire has no affordability gate — a 0-gold leader is driven to -1 (pinned current behavior).")
	harness.check(mill.hired_unit.shown == true,
		"lumberjack_hire still hires (show called) despite unaffordable cost.")

	spawns.free()
	ws.restore()
