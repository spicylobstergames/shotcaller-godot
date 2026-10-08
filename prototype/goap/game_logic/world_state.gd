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
