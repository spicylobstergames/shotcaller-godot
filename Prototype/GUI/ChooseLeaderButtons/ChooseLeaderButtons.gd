extends Control

export(ButtonGroup) var leader_group

export(PackedScene) var curent_leader

var leader_name:String

func _ready() -> void:
	leader_name = leader_group.get_pressed_button().name
	curent_leader = Leaders[leader_name]
	
	Game.connect("playing", self, "_on_Game_playing")

	
func _on_Game_playing() -> void:
	hide()

func _on_button_pressed(pressed):
	var pressed_button = leader_group.get_pressed_button()
	if pressed and leader_name != pressed_button.name:
		leader_name = pressed_button.name
		curent_leader = Leaders[leader_name]
