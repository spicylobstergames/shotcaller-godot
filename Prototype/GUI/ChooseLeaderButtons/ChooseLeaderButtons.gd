extends Control

export(ButtonGroup) var leader_group

export(PackedScene) var curent_leader

onready var leaders = {
#	"daniel": preload("res://Character/Child/Leader/DEBUG_Daniel/Daniel.tscn"),	
	"maori": preload("res://Character/Child/Leader/Maori/Maori.tscn"),
	"raja": preload("res://Character/Child/Leader/Raja/Raja.tscn"),
	"robin": preload("res://Character/Child/Leader/Robin/Robin.tscn"),
	"rollo": preload("res://Character/Child/Leader/Rollo/Rollo.tscn"),
	"sami": preload("res://Character/Child/Leader/Sami/Sami.tscn")
}

var leader_name

func _ready() -> void:
	var pressed_button = leader_group.get_pressed_button()
	leader_name = pressed_button.name
	curent_leader = leaders[leader_name]
	
	Game.connect("playing", self, "_on_Game_playing")

	
func _on_Game_playing() -> void:
	hide()

func _on_button_pressed(pressed):
	var pressed_button = leader_group.get_pressed_button()
	if pressed and leader_name != pressed_button.name:
		leader_name = pressed_button.name
		curent_leader = leaders[leader_name]
