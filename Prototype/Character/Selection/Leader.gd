extends Control

var curent_leader = "maori"

onready var maori_button = find_node(curent_leader)
onready var group = maori_button.group

func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")

	
func _on_Game_playing() -> void:
	hide()

func _on_button_pressed(pressed):
	var pressed_button = group.get_pressed_button()
	if pressed and curent_leader != pressed_button.name:		
		curent_leader = pressed_button.name
		#print(curent_leader)
