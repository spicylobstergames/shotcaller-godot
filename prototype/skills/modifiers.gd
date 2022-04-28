extends Node
var game:Node

# self = game.unit.modifiers

var extra_retreat_speed = 10

var retreat_regen = 10

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
	
	match mod_str:
		"speed": default = get_speed(unit)
		"regen": default = get_regen(unit)
		"attack_range": default = get_att_range(unit)
	
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


func get_regen(unit):
	var default = unit.regen
	if unit.retreating: default += retreat_regen
	return default


func get_att_range(unit):
	return unit.attack_hit_radius * unit.attack_range



func add(unit, mod_str, mod_name, value):
	unit.current_modifiers[mod_str].append({
		"name": mod_name,
		"value": value
	})


func remove(unit, mod_str, mod_name):
	for modifier in unit.current_modifiers[mod_str]:
		if modifier.name == mod_name:
			unit.current_modifiers[mod_str].erase(modifier)
