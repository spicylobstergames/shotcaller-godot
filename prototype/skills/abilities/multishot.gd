extends Node

@onready var unit: Unit = get_parent().get_parent().get_parent()

@export var icon: Texture2D
@export var ability_name := "Multishot"
@export var description := "This unit can shoot at all enemy characters in range"
@export var status_effect_icon: Texture2D
@export var skill_type := "passive"

func _ready() -> void:
	unit.status_effects["multishot"] = {
		"icon": status_effect_icon,
		"hint": "Multishot: target all enemies in range"
	}
