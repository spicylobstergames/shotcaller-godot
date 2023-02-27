extends Node


# WorldState global class

# This class is an Autoload accessible globaly
# Access the autoload list in godot settings


onready var game = get_tree().get_current_scene()

#runs logic that is only run once per second
var one_sec_timer = Timer.new()
var time:int = 0

enum teams { red, blue }

enum leaders { arthur, bokuden, hongi, joan, lorne, nagato, osman, raja, robin , rollo , sida , takoda , tomyris }

enum pawns_list { infantry, archer, mounted }

enum neutrals_list { lumberjack }

var lanes = {}

var _state = {}


func get_state(state_name, default = null):
	return _state.get(state_name, default)


func set_state(state_name, value):
	_state[state_name] = value


func clear_state():
	_state = {}


func apply_cheat_code(code):
	match code:
		"SHADOW":
			for unit1 in game.all_units:
				if unit1.has_node("light"): unit1.get_node("light").shadow_enabled = false
		"WIN":
			game.end(true)
		"LOSE":
			game.end(false)

