extends Node

onready var unit : Unit = get_parent().get_parent().get_parent()
onready var game = get_tree().get_current_scene()
var affected_units = {}

const RANGE = 100
const VALUE = 2

export var icon : Texture
export var ability_name = "Aura of Courage"
export(String, MULTILINE) var description = "Arthur inspires courage in nearby allies, increasing their attack by 2 * his level"


func _on_update_timer_timeout():
	$update_timer.start()
	for other_unit in affected_units.keys():
		if (other_unit.global_position - unit.global_position).length() > RANGE:
			other_unit.modifiers.remove(other_unit, "damage", "aura_of_courage")
			affected_units.erase(other_unit)
	
	for other_unit in game.map.blocks.get_units_in_radius(unit.global_position, 200):
		if other_unit.team == unit.team and unit.type != "building":
			other_unit.modifiers.remove(other_unit, "damage", "aura_of_courage")
			other_unit.modifiers.add(other_unit, "damage", "aura_of_courage", VALUE * unit.level)
			affected_units[other_unit] = true
