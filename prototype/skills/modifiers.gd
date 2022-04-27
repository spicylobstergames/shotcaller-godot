extends Node
var game:Node

# self = game.unit.modifiers

var extra_retreat_speed = 10


func _ready():
	game = get_tree().get_current_scene()


func new_modifiers():
	return {
		"hp": [],
		"regen": [],
		"vision": [],
		"speed":[],
		"damage": [],
		"attack_range": [],
		"attack_speed": [],
		"defense": []
	}


func get_value(unit, mod_str):
	var default = unit[mod_str]
	
	if mod_str == "speed":
		default = get_speed(unit)
	
	for modifier in unit.current_modifiers[mod_str]:
		default += modifier.value
	
	return default


func get_speed(unit):
	var default = unit.speed
	
	if unit.hunting:
		default = unit.hunting_speed
	elif unit.retreating:
		var bonus = game.unit.skills.get_value(unit, "bonus_retreat_speed")
		default += extra_retreat_speed + bonus
	
	default += game.unit.orders.tactics_extra_speed[unit.tactics]
	
	return default


func add_modifier(unit, mod_str, mod_name, value):
	unit.current_modifiers[mod_str].append({
		"name": mod_name,
		"value": value
	})


func remove_modifier(unit, mod_str, mod_name):
	for modifier in unit.current_modifiers[mod_str]:
		if modifier.name == mod_name:
			unit.current_modifiers[mod_str].erase(modifier)
