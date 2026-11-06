extends Node

# self = Modifiers

const TACTICS_EXTRA_SPEED = {"retreat": 0, "defend": -5, "default": 0, "attack": 5}

var extra_retreat_speed = 10

var retreat_regen = 10

@export var hp_per_level : float = 10
@export var regen_per_level : float = 2
@export var damage_per_level : float = 2.5
@export var defense_per_level : float = 2
@export var attack_speed_per_level : float = 0.05


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
	if not unit: return 0
	var default: float = 0.0

	# Access the base value based on the modifier type.
	match mod_str:
		"speed": default = get_velocity(unit)
		"regen": default = get_regen(unit)
		"attack_range": default = get_att_range(unit)
		_:
			# For other types, read from the unit directly.
			match mod_str:
				"hp": default = float(unit.hp)
				"vision": default = float(unit.vision)
				"damage": default = float(unit.damage)
				"defense": default = float(unit.defense)
				"attack_speed": default = float(unit.attack_speed)
				_: default = 0.0

	# Sum modifier stack.
	if unit.current_modifiers.has(mod_str):
		for modifier in unit.current_modifiers[mod_str]:
			if modifier and modifier.has("value"):
				default += float(modifier.value)

	# Add level bonus.
	var level_bonus = 0
	if unit.level > 0:
		level_bonus = unit.level - 1
	match mod_str:
		"hp": level_bonus *= hp_per_level
		"regen": level_bonus *= regen_per_level
		"damage": level_bonus *= damage_per_level
		"defense": level_bonus *= defense_per_level
		"attack_speed": level_bonus *= attack_speed_per_level

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
	var default: float = 10.0  # Safe default

	# Read speed - try property access, fall back to 10.
	if "speed" in unit:
		default = float(unit.speed)

	if unit.agent:
		var hunting: bool = false
		var retreating: bool = false
		if unit.agent.has_method("get_state"):
			hunting = unit.agent.get_state("hunting", false) == true
			retreating = unit.agent.get_state("is_retreating", false) == true
		if hunting and unit.target and unit.target.agent:
			if unit.target.agent.get_state("is_retreating", false) != true:
				if "hunting_speed" in unit:
					default = float(unit.hunting_speed)
		if retreating:
			var bonus = Skills.get_value(unit, "bonus_retreat_speed")
			if bonus == null: bonus = 0
			default += extra_retreat_speed + bonus

	var tactic = "default"
	if unit.agent and unit.agent.has_method("get_state"):
		tactic = unit.agent.get_state("tactic", "default")
	default += TACTICS_EXTRA_SPEED.get(tactic, 0)

	return default


func get_regen(unit):
	var default: float = 0.0
	if unit and "regen" in unit:
		default = float(unit.regen)
	if unit and unit.agent and unit.agent.get_state("is_retreating", false) == true:
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
