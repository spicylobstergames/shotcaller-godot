extends Node

@onready var unit: Unit = get_owner() as Unit
@export var skill_data: SkillResource

func _ready() -> void:
	unit.status_effects["critical slash"] = {
		"icon": skill_data.status_effect_icon,
		"hint": skill_data.status_effect_hint
	}
