extends RefCounted

# Snapshot/restore helper for WorldState keys touched by tests.
#
# Every test that mutates WorldState MUST restore what it touched — leaked
# state makes the suite order-dependent (a test can only pass if it runs
# after another test happened to set things up).
#
# Absence-aware: a key that did not exist before the test is ERASED on
# restore, not set to null. Setting it to null would poison the key —
# WorldState.get_state(key, default) returns null when the key exists with a
# null value, defeating typed defaults in production code
# (e.g. `is_valid() -> bool: return WorldState.get_state("is_game_active", false)`).
#
# Usage:
#   var ws = WorldStateSnapshot.new()
#   ws.capture(["player_team", "player_leaders", "player_extra_unit"])
#   ... test (use ws.set_state or WorldState.set_state) ...
#   ws.restore()   # put every captured key back

var _saved: Dictionary = {}


func capture(keys: Array) -> void:
	for key in keys:
		_saved[key] = {
			"existed": WorldState._state.has(key),
			"value": WorldState.get_state(key),
		}


func set_state(key: String, value) -> void:
	if not _saved.has(key):
		capture([key])
	WorldState.set_state(key, value)


func restore() -> void:
	for key in _saved:
		if _saved[key]["existed"]:
			WorldState.set_state(key, _saved[key]["value"])
		else:
			WorldState._state.erase(key)
	_saved.clear()
