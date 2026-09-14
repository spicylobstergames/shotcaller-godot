extends Node

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
