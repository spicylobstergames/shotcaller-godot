extends Node

@onready var unit: Unit = get_parent().get_parent().get_parent()
@onready var game: Node = get_tree().get_current_scene()
var affected_units = {}

const RANGE = 100
const VALUE = 2

@export var icon : Texture2D
@export var ability_name = "Multishot"
@export var description = "This unit can shoot at all enemy characters in range" # (String, MULTILINE)
@export var status_effect_icon : Texture2D

func _ready():
	unit.status_effects["multishot"] = {
		icon = status_effect_icon,
		hint = "Multishot: target all enemies in range"
	}
