extends Node

@onready var unit: Unit = get_parent().get_parent().get_parent()

const VALUE := 5

@export var icon: Texture2D
@export var ability_name := "Trader"
@export var description := "Osman can barter the price of items down by 5 times his level percent"
@export var status_effect_icon: Texture2D
@export var skill_type := "passive"

func _ready() -> void:
	unit.status_effects["Trader"] = {
		"icon": status_effect_icon,
		"hint": "Trader: Reduces item costs by %d%%" % (VALUE * unit.level)
	}
