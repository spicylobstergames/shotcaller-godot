extends Node

onready var unit: Unit = get_parent().get_parent().get_parent()
onready var game:Node = get_tree().get_current_scene()

const RANGE = 100
const VALUE = 5

export var icon: Texture
export var ability_name = "Trader"
export(String, MULTILINE) var description = "Osman can barter the price of items down by 5 times his level percent"
export var status_effect_icon : Texture


func _ready():
	unit.status_effects["Trader"] = {
		icon = status_effect_icon,
		hint = str("Trader: Reduces item costs by ", VALUE * unit.level, "%" )
	}
