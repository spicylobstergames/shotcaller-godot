extends Node

@onready var unit: Unit = get_parent().get_parent().get_parent()
@onready var game:Node = get_tree().get_current_scene()

@export var icon : Texture2D
@export var ability_name = "Critical slash"
@export var description = "Gives Bokuden a chance to deal critical damage on each attack." # (String, MULTILINE)

@export var status_effect_icon : Texture2D

func _ready():
	unit.status_effects["critical slash"] = {
		icon = status_effect_icon,
		hint = "Critical slash: chance to deal critical damage"
	}
