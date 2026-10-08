extends Node

@onready var unit: Unit = get_parent().get_parent().get_parent()

@export var skill_data: SkillResource

func _ready() -> void:
	unit.status_effects["multishot"] = {
		"icon": skill_data.status_effect_icon,
		"hint": skill_data.status_effect_hint
	}
