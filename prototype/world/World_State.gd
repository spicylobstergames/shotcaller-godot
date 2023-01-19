# This class is an Autoload accessible globaly
# Access the autoload list in godot settings

extends Node

enum teams { red, blue }

enum leaders { arthur, bokuden, hongi, joan, lorne, nagato, osman, raja, robin , rollo , sida , takoda , tomyris }

enum pawns_list { infantry, archer, mounted }

enum neutrals_list { lumberjack }


var _state = {}


func get_state(state_name, default = null):
	return _state.get(state_name, default)


func set_state(state_name, value):
	_state[state_name] = value


func clear_state():
	_state = {}


func get_elements(group_name):
	return self.get_tree().get_nodes_in_group(group_name)

