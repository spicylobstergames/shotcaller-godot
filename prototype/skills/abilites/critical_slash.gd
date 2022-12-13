extends Node

onready var unit : Unit = get_parent().get_parent().get_parent()
onready var game = get_tree().get_current_scene()

export var icon : Texture
export var ability_name = "Critical slash"
export(String, MULTILINE) var description = "Gives Bokuden a chance to deal critical damage on each attack."

export var status_effect_icon : Texture

func _ready():
	unit.status_effects["critical slash"] = {
		icon = status_effect_icon,
		hint = "Critical slash: chance to deal critical damage"
	}
