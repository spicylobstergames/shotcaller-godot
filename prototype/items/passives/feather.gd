extends Node

onready var unit : Unit = get_parent().get_parent().get_parent()
onready var game = get_tree().get_current_scene()
var affected_units = {}

const RANGE = 100
const VALUE = 10

export var icon : Texture
export var ability_name = "Magic Feather"
export(String, MULTILINE) var description = "The feather helps nearby units move across the battlefield"
export var status_effect_icon : Texture

func _on_update_timer_timeout():
	$update_timer.start()
	for other_unit in affected_units.keys():
		if (other_unit.global_position - unit.global_position).length() > RANGE:
			other_unit.modifiers.remove(other_unit, "speed", "feather")
			affected_units.erase(other_unit)
			other_unit.status_effects.erase("feather")

	for other_unit in game.map.blocks.get_units_in_radius(unit.global_position, 200):
		if other_unit.team == unit.team and unit.type != "building":
			other_unit.modifiers.remove(other_unit, "speed", "feather")
			other_unit.modifiers.add(other_unit, "speed", "feather", VALUE)
			affected_units[other_unit] = true
			other_unit.status_effects["feather"] = {
				icon = status_effect_icon,
				hint = "Feather: Increases speed by %d" % (VALUE)
			}
