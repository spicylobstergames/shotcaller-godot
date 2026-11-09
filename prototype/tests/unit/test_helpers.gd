extends RefCounted

# Self-tests for the shared test helpers. These make the helpers load-bearing:
# if a helper breaks, the suite goes RED instead of silently weakening every
# test that depends on it.

const WorldStateSnapshot = preload("res://tests/helpers/world_state_snapshot.gd")
const MockGoal = preload("res://tests/helpers/mock_goal.gd")


func run(harness) -> void:
	_test_world_state_snapshot_restores(harness)
	_test_world_state_snapshot_auto_captures(harness)
	_test_world_state_snapshot_restores_null(harness)
	_test_mock_goal_tracks_calls(harness)


func _test_world_state_snapshot_restores(harness) -> void:
	var original = WorldState.get_state("player_team")
	WorldState.set_state("player_team", "sentinel-original")
	var ws = WorldStateSnapshot.new()
	# First touch captures "sentinel-original".
	ws.set_state("player_team", "blue")
	# Mutate again through the snapshot and directly — neither is captured.
	ws.set_state("player_team", "red")
	WorldState.set_state("player_team", "neutral")
	ws.restore()
	harness.check_equal(WorldState.get_state("player_team"), "sentinel-original",
		"WorldStateSnapshot.restore() puts captured keys back (helper is load-bearing).")
	WorldState.set_state("player_team", original)


func _test_world_state_snapshot_auto_captures(harness) -> void:
	var before = WorldState.get_state("enemy_team")
	var ws = WorldStateSnapshot.new()
	# First touch via the snapshot captures the pre-existing value...
	ws.set_state("enemy_team", "green")
	# ...so restore() returns it even though capture() was never called.
	ws.restore()
	harness.check_equal(WorldState.get_state("enemy_team"), before,
		"WorldStateSnapshot auto-captures on first set_state touch.")


func _test_world_state_snapshot_restores_null(harness) -> void:
	var ws = WorldStateSnapshot.new()
	# A key that did not exist before must be REMOVED-able: restoring the
	# captured null puts a null back (get_state default), not a stale value.
	ws.set_state("player_extra_unit", "infantry")
	ws.restore()
	harness.check(WorldState.get_state("player_extra_unit") == null,
		"WorldStateSnapshot restores a captured null (absent key) correctly.")


func _test_mock_goal_tracks_calls(harness) -> void:
	var goal = MockGoal.new(true, 7)
	harness.check_equal(goal.valid_calls, 0,
		"MockGoal starts with zero is_valid calls.")
	harness.check(goal.is_valid(null), "MockGoal.is_valid returns the configured validity.")
	harness.check_equal(goal.valid_calls, 1,
		"MockGoal counts is_valid calls.")
	harness.check_equal(goal.priority(null), 7, "MockGoal.priority returns the configured priority.")
	harness.check_equal(goal.priority_calls, 1, "MockGoal counts priority calls.")

	# Side-effect callback fires inside is_valid, before the validity check.
	var fired := {"count": 0}
	var side = MockGoal.new(false, 1)
	side.on_valid = func(): fired.count += 1
	harness.check(side.is_valid(null) == false, "MockGoal respects configured invalidity.")
	harness.check_equal(fired.count, 1,
		"MockGoal fires on_valid during is_valid, even when invalid.")
