extends Node


# WorldState global class

# This class is an Autoload accessible globaly
# Access the autoload list in godot settings


onready var game = get_tree().get_current_scene()

enum teams { red, blue }

enum leaders { arthur, bokuden, hongi, joan, lorne, nagato, osman, raja, robin , rollo , sida , takoda , tomyris }

enum pawns_list { infantry, archer, mounted }

enum neutrals_list { lumberjack }


#runs logic that is only run once per second
var one_sec_timer = Timer.new()

func start_one_sec_timer():
	one_sec_timer.wait_time = 1
	add_child(one_sec_timer)
	one_sec_timer.start()



func apply_cheat_code(code):
	print(code)
	match code:
		"SHADOW":
			for unit1 in game.all_units:
				if unit1.has_node("light"): unit1.get_node("light").shadow_enabled = false
		"WIN":
			game.end(true)
		"LOSE":
			game.end(false)


var _state = {}


func get_state(state_name, default = null):
	return _state.get(state_name, default)


func set_state(state_name, value):
	_state[state_name] = value


func clear_state():
	_state = {}



