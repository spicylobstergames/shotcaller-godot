extends Node

onready var unit : Unit = get_parent().get_parent().get_parent()
onready var game = get_tree().get_current_scene()
var affected_units = {}

const RANGE = 100
const VALUE = 2

export var icon : Texture
export var ability_name = "Multishot"
export(String, MULTILINE) var description = "This unit can shoot at all enemy characters in range"
export var status_effect_icon : Texture

func _ready():
	unit.status_effects["mutlishot"] = {
		icon = status_effect_icon,
		hint = "Multishot: target all enemies in range"
	}
