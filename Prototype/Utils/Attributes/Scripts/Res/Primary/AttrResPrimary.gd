tool
extends AttrRes
class_name AttrResPrimary

export(Units.TeamID) var unit_team = Units.TeamID.None
export(Units.TypeID) var unit_type = Units.TypeID.None
export(bool) var mirror_mode = false


func on_ready() -> void:
	_saved_init_properties["unit_team"] = unit_team
	_saved_init_properties["unit_type"] = unit_type
	_saved_init_properties["mirror_mode"] = mirror_mode
