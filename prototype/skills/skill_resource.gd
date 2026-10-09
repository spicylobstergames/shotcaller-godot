extends Resource

class_name SkillResource

@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("active", "passive") var skill_type: String = "passive"
@export var cooldown: int = 0
@export var visualize: String = "none"
@export var attributes: Dictionary = {}
@export var icon: Texture2D
@export var status_effect_icon: Texture2D
@export var status_effect_hint: String = ""
