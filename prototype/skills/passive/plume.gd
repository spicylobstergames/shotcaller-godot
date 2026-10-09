extends Node

@onready var unit: Unit = get_owner() as Unit
var affected_units: Dictionary = {}

@export var skill_data: SkillResource

func _on_update_timer_timeout() -> void:
	$update_timer.start()
	for other_unit in affected_units.keys():
		if (other_unit.global_position - unit.global_position).length() > skill_data.attributes.range:
			other_unit.modifiers.remove(other_unit, "speed", "feather")
			affected_units.erase(other_unit)
			other_unit.status_effects.erase("feather")

	for other_unit in unit.units_in_radius:
		if other_unit.team == unit.team and unit.type != "building":
			other_unit.modifiers.remove(other_unit, "speed", "feather")
			other_unit.modifiers.add(other_unit, "speed", "feather", skill_data.attributes.value)
			affected_units[other_unit] = true
			other_unit.status_effects["feather"] = {
				"icon": skill_data.status_effect_icon,
				"hint": skill_data.status_effect_hint % skill_data.attributes.value
			}
