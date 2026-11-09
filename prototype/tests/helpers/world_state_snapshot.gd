extends RefCounted

# Snapshot/restore helper for WorldState keys touched by tests.
#
# Every test that mutates WorldState MUST restore what it touched — leaked
# state makes the suite order-dependent (a test can only pass if it runs
# after another test happened to set things up).
#
# Usage:
#   var ws = WorldStateSnapshot.new()
#   ws.capture(["player_team", "player_leaders", "player_extra_unit"])
#   WorldState.set_state("player_team", "blue")
#   ... test ...
#   ws.restore()   # put every captured key back

var _saved: Dictionary = {}


func capture(keys: Array) -> void:
	for key in keys:
		_saved[key] = WorldState.get_state(key)


func set_state(key: String, value) -> void:
	if not _saved.has(key):
		_saved[key] = WorldState.get_state(key)
	WorldState.set_state(key, value)


func restore() -> void:
	for key in _saved:
		WorldState.set_state(key, _saved[key])
	_saved.clear()
