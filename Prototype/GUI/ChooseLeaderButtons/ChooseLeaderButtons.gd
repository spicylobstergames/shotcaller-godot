extends Control

export(ButtonGroup) var leader_group

export(PackedScene) var curent_leader

onready var maori = preload("res://Character/Child/Leader/Maori/Maori.tscn")
onready var raja =  preload("res://Character/Child/Leader/Raja/Raja.tscn")
onready var robin = preload("res://Character/Child/Leader/Robin/Robin.tscn")
onready var rollo = preload("res://Character/Child/Leader/Rollo/Rollo.tscn")
onready var sami =  preload("res://Character/Child/Leader/Sami/Sami.tscn")

var leader_name

func _ready() -> void:
	var pressed_button = leader_group.get_pressed_button()
	leader_name = pressed_button.name
	curent_leader = self[leader_name]
	
	Game.connect("playing", self, "_on_Game_playing")

	
func _on_Game_playing() -> void:
	hide()

func _on_button_pressed(pressed):
	var pressed_button = leader_group.get_pressed_button()
	if pressed and leader_name != pressed_button.name:
		leader_name = pressed_button.name
		curent_leader = self[leader_name]
