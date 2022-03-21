extends Control

var leader_group:ButtonGroup

var _curent_leader:PackedScene

var _leader_name:String

# TODO select multiple leaders

func _ready() -> void:
	_leader_name = leader_group.get_pressed_button().name
	_curent_leader = Leaders[_leader_name]
	
	Game.connect("playing", self, "_on_Game_playing")

	
func _on_Game_playing() -> void:
	hide()

func _on_button_pressed(pressed):
	var pressed_button = leader_group.get_pressed_button()
	if pressed and _leader_name != pressed_button.name:
		_leader_name = pressed_button.name
		_curent_leader = Leaders[_leader_name]
