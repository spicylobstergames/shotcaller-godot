extends Node

# self = Modifiers

const KNOWN_MODIFIERS := ["hp", "regen", "vision", "speed", "damage", "attack_range", "attack_speed", "defense", "dot"]
const TACTICS_EXTRA_SPEED = {"retreat": 0, "defend": -5, "default": 0, "attack": 5}

var extra_retreat_speed = 10

var retreat_regen = 10

@export var hp_per_level : float = 10
@export var regen_per_level : float = 2
@export var damage_per_level : float = 2.5
@export var defense_per_level : float = 2
@export var attack_speed_per_level : float = 0.05


func _is_known_modifier(mod_str: String) -> bool:
	return mod_str in KNOWN_MODIFIERS


func new_modifiers():
	return {
		"hp": [],
		"regen": [],
		"vision": [],
		"speed":[],
		"damage": [],
		"attack_range": [],
		"attack_speed": [],
		"defense": [],
		"dot": []
	}


func get_value(unit, mod_str):
	if not _is_known_modifier(mod_str):
		push_warning("Modifiers.get_value: unknown modifier name \"%s\". Known: %s" % [mod_str, KNOWN_MODIFIERS])

	var unit_level_val = unit.get("level")
	var unit_mods_val = unit.get("current_modifiers")

	var default: float = 0.0

	match mod_str:
		"speed": default = get_velocity(unit)
		"regen": default = get_regen(unit)
		"attack_range": default = get_att_range(unit)
		_:
			var val = unit.get(mod_str)
			if val != null:
				default = float(val)

	var level_bonus = 0
	if unit_level_val != null:
		level_bonus = int(unit_level_val) - 1
	match mod_str:
		"hp": level_bonus *= hp_per_level
		"regen": level_bonus *= regen_per_level
		"damage": level_bonus *= damage_per_level
		"defense": level_bonus *= defense_per_level
		"attack_speed": level_bonus *= attack_speed_per_level

	if typeof(unit_mods_val) == TYPE_DICTIONARY and unit_mods_val.has(mod_str):
		for modifier in unit_mods_val[mod_str]:
			if typeof(modifier) == TYPE_DICTIONARY and modifier.has("value"):
				default += float(modifier.value)

	return default + level_bonus


func get_dot(unit):
	var dot_effects = []
	if not unit.current_modifiers["dot"].is_empty():
		for modifier in unit.current_modifiers["dot"]:
			dot_effects.append(modifier.value)
		return dot_effects
	else:
		return null


func get_velocity(unit):
	if not unit: return 0
	var default: float = 0.0
	var speed_val = unit.get("speed")
	if speed_val != null:
		default = float(speed_val)

	var agent = unit.get("agent")
	if agent:
		var hunting: bool = false
		var retreating: bool = false
		var h = agent.get_state("hunting")
		if h != null:
			hunting = h == true
		var r = agent.get_state("is_retreating")
		if r != null:
			retreating = r == true
		if hunting and unit.target and unit.target.get("agent"):
			var tr = unit.target.agent.get_state("is_retreating")
			if tr != true:
				var hs = unit.get("hunting_speed")
				if hs != null:
					default = float(hs)
		if retreating:
			var bonus = Skills.get_value(unit, "bonus_retreat_speed")
			if bonus == null: bonus = 0
			default += extra_retreat_speed + bonus

	var tactic = "default"
	if agent:
		var t = agent.get_state("tactic")
		if t != null:
			tactic = t
	default += TACTICS_EXTRA_SPEED.get(tactic, 0)

	return default


func get_regen(unit):
	var default: float = 0.0
	if unit:
		var r = unit.get("regen")
		if r != null:
			default = float(r)
	if unit:
		var agent = unit.get("agent")
		if agent:
			var ret = agent.get_state("is_retreating")
			if ret == true:
				default += retreat_regen
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
