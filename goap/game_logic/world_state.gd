# =============================================================================
# GOAP-GUIDE: WorldState autoload (goap/game_logic/world_state.gd)
# =============================================================================
# Global string-keyed store shared by the game and the planner. The planner
# reads it as a fallback source of facts after agent state, so every key here
# is a cross-file contract (see docs/ai/world-state.md).
#   get_state(name, default) -> returns default only when the key is ABSENT.
#       ALWAYS pass a default from a typed (-> bool) caller: a key that exists
#       holding null still returns null and breaks the return type.
#   second_elapsed -> emitted once per game second; the Agent uses it for
#       regen, damage-over-time and per-second action/goal callbacks.
# Timers: setup_timers()/setup_spawn_timers() add child Timers and are NOT
# idempotent (a second game.start() adds new timers) -- see
# IMPROVEMENT_PLAN.md Track E4.
# =============================================================================

extends Node

signal second_elapsed

# WorldState global class.
# This class is an autoload accessible globally.
# Access the autoload list in the Godot settings.

# Runs logic that is only executed once per second.
var one_sec_timer: Timer

# Controls creep spawn rate.
var spawn_timer: Timer

enum teams { red, blue }
enum pawns_list { infantry, archer, mounted }
enum neutrals_list { mailboy, lumberjack }
enum leaders_list {
	arthur,
	bokuden,
	hongi,
	joan,
	lorne,
	nagato,
	osman,
	raja,
	robin,
	rollo,
	sida,
	takoda,
	tomyris,
}

var _state: Dictionary = {}


# Returns the stored value, or `default` when the key is ABSENT. A key that
# exists with a null value still returns null -- typed (-> bool) callers must
# pass a default and must not rely on this to coerce null.
func get_state(state_name, default = null):
	if _state.has(state_name):
		return _state[state_name]
	return default


func set_state(state_name, value):
	_state[state_name] = value


func clear_state():
	_state.clear()
	
func setup_timers():
	one_sec_timer = Timer.new()
	one_sec_timer.wait_time = 1
	one_sec_timer.name = "one_sec_timer"
	one_sec_timer.timeout.connect(_emit_second_elapsed)
	add_child(WorldState.one_sec_timer)
	
func setup_spawn_timers(spawn_time):
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_time
	spawn_timer.name = "unit_spawn_timer"
	spawn_timer.one_shot = true
	add_child(WorldState.spawn_timer)

func _emit_second_elapsed() -> void:
	second_elapsed.emit()

func stop_timers():
	one_sec_timer.stop()
	spawn_timer.stop()
