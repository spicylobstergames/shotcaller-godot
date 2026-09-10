extends Node

@onready var unit: Unit = get_parent().get_parent().get_parent()

@export var icon: Texture2D
@export var ability_name := "Critical Slash"
@export var description := "Gives Bokuden a chance to deal critical damage on each attack."

@export var status_effect_icon: Texture2D
@export var skill_type := "passive"

func _ready() -> void:
	unit.status_effects["critical slash"] = {
		"icon": status_effect_icon,
		"hint": "Critical slash: chance to deal critical damage"
	}
