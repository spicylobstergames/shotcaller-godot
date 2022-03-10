extends Control

var curent_leader_name = 'maori'

onready var selected_button = find_node(curent_leader_name)
onready var group = selected_button.group

onready var leaders = {
	"daniel": preload("res://Character/Child/Leader/DEBUG_Daniel/Daniel.tscn"),	
	"maori": preload("res://Character/Child/Leader/Maori/Maori.tscn"),
	"raja": preload("res://Character/Child/Leader/Raja/Raja.tscn"),
	"robin": preload("res://Character/Child/Leader/Robin/Robin.tscn"),
	"rollo": preload("res://Character/Child/Leader/Rollo/Rollo.tscn"),
	"sami": preload("res://Character/Child/Leader/Sami/Sami.tscn")
}

onready var curent_leader = leaders[curent_leader_name]

func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")

	
func _on_Game_playing() -> void:
	hide()

func _on_button_pressed(pressed):
	var pressed_button = group.get_pressed_button()
	
	if pressed and curent_leader_name != pressed_button.name:
		curent_leader = leaders[pressed_button.name]
		#print(curent_leader)
