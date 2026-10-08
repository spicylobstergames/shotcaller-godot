extends Node

@export var unit: Unit
@export var skill_data: SkillResource

func _ready() -> void:
	unit.status_effects["critical slash"] = {
		"icon": skill_data.status_effect_icon,
		"hint": skill_data.status_effect_hint
	}
