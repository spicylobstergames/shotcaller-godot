extends Node

@export var unit: Unit

var affected_units: Dictionary = {}

@export var skill_data: SkillResource

func _on_update_timer_timeout() -> void:
	$update_timer.start()
	for other_unit in affected_units.keys():
		if (other_unit.global_position - unit.global_position).length() > skill_data.attributes.range:
			Goap.modifiers.remove(other_unit, "damage", "aura_of_courage")
			affected_units.erase(other_unit)
			other_unit.status_effects.erase("aura_of_courage")
	
	for other_unit in unit.units_in_radius:
		if other_unit.team == unit.team and unit.type != "building":
			Goap.modifiers.remove(other_unit, "damage", "aura_of_courage")
			Goap.modifiers.add(other_unit, "damage", "aura_of_courage", skill_data.attributes.value * unit.level)
			affected_units[other_unit] = true
			other_unit.status_effects["aura_of_courage"] = {
				"icon": skill_data.status_effect_icon,
				"hint": skill_data.status_effect_hint % (skill_data.attributes.value * unit.level)
			}
