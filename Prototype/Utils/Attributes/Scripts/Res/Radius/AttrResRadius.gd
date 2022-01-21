tool
extends AttrRes
class_name AttrResRadius

export(float) var collision_size = 0.0
export(float) var attack_range = 0.0
export(float) var unit_detection = 0.0
export(float) var area_selection = 0.0
export(Dictionary) var hurt_area = {
	radius = 0.0,
	height = 0.0
}


func on_ready() -> void:
	_saved_init_properties["collision_size"] = collision_size
	_saved_init_properties["attack_range"] = attack_range
	_saved_init_properties["unit_detection"] = unit_detection
	_saved_init_properties["area_selection"] = area_selection
