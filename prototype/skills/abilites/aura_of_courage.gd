extends Node

onready var unit : Unit = get_parent().get_parent().get_parent()
onready var game = get_tree().get_current_scene()
var affected_units = {}

const RANGE = 100
const VALUE = 2

export var icon : Texture
export var ability_name = "Aura of Courage"
export(String, MULTILINE) var description = "Arthur inspires courage in nearby allies, increasing their attack by 2 * his level"
export var status_effect_icon : Texture

func _on_update_timer_timeout():
	$update_timer.start()
	for other_unit in affected_units.keys():
		if (other_unit.global_position - unit.global_position).length() > RANGE:
			Behavior.modifiers.remove(other_unit, "damage", "aura_of_courage")
			affected_units.erase(other_unit)
			other_unit.status_effects.erase("aura_of_courage")
	
	for other_unit in unit.units_in_radius:
		if other_unit.team == unit.team and unit.type != "building":
			Behavior.modifiers.remove(other_unit, "damage", "aura_of_courage")
			Behavior.modifiers.add(other_unit, "damage", "aura_of_courage", VALUE * unit.level)
			affected_units[other_unit] = true
			other_unit.status_effects["aura_of_courage"] = {
				icon = status_effect_icon,
				hint = "Courage: Increases damage by %d" % (VALUE * unit.level)
			}
