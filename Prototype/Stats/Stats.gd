tool
extends Node

signal changed(properties)

var unit_type: int = 0
var team: int = 0

var state_behavior: int = 0
var state_action: int = 0
var state_reaction: int = 0

var stats_health: int = 0
var stats_max_health: int = 0
var stats_mana: int = 0
var stats_max_mana: int = 0
var stats_leader_damage = 0
var stats_creep_damage = 0
var stats_building_damage = 0
var stats_attack_speed: int = 0
var stats_movement_speed: int = 0

var area_unit: int = 0 
var area_attack_range: int = 0
var area_selection: int = 0
var area_unit_detection: int = 0 
var area_distance_between_units: int = 0 

func _get_property_list() -> Array:
	var properties = []

	properties.append({
			name = "team",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = PoolStringArray(Units.TeamID.keys()).join(","),
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "unit_type",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = PoolStringArray(Units.TypeID.keys()).join(","),
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
		name = "State",
		type = TYPE_NIL,
		hint_string = "state_",
		usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
			name = "state_behavior",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = PoolStringArray(Units.BehaviorStateID.keys()).join(","),
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "state_action",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = PoolStringArray(Units.ActionStateID.keys()).join(","),
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "state_reaction",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = PoolStringArray(Units.ReactionStateID.keys()).join(","),
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
		name = "Statistics",
		type = TYPE_NIL,
		hint_string = "stats_",
		usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
			name = "stats_health",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,1000,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "stats_max_health",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,1000,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "stats_mana",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,1000,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "stats_max_mana",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,1000,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "stats_leader_damage",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "stats_creep_damage",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "stats_building_damage",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "stats_attack_speed",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "stats_movement_speed",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
		name = "Area",
		type = TYPE_NIL,
		hint_string = "area_",
		usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
			name = "area_attack_range",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "area_unit",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "area_selection",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "area_unit_detection",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})
	properties.append({
			name = "area_distance_between_units",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,500,1",
			usage = PROPERTY_USAGE_DEFAULT
		})

	return properties


func change(properties: Array) -> void:
	var _updated_props = []
	for p in properties:
		if get(p.name) != null:
			set(p.name, p.value)
			_updated_props.append({name = p.name, value = get(p.name)})
	emit_signal("changed", _updated_props)
