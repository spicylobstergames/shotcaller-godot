tool
extends AttrRes
class_name AttrResStats

export(float) var health = 0.0
export(float) var max_health = 0.0
export(float) var health_regeneration_rate = 0.0
export(float) var health_regeneration_step = 0.0

export(float) var mana = 0.0
export(float) var max_mana = 0.0
export(float) var mana_regeneration_rate = 0.0
export(float) var mana_regeneration_step = 0.0

export(float) var move_speed = 0.0
export(float) var move_acceleration = 0.0
export(float) var attack_speed = 0.0

export(float) var damage = 0.0


func on_ready() -> void:
	_saved_init_properties["health"] = health
	_saved_init_properties["max_health"] = max_health
	_saved_init_properties["health_regeneration_rate"] = health_regeneration_rate
	_saved_init_properties["health_regeneration_step"] = health_regeneration_step
	_saved_init_properties["mana"] = mana
	_saved_init_properties["max_mana"] = max_mana
	_saved_init_properties["mana_regeneration_rate"] = mana_regeneration_rate
	_saved_init_properties["mana_regeneration_step"] = mana_regeneration_step
	_saved_init_properties["move_speed"] = move_speed
	_saved_init_properties["move_acceleration"] = move_acceleration
	_saved_init_properties["attack_speed"] = attack_speed
	_saved_init_properties["damage"] = damage


func on_update(attribute: Node, delta: float) -> void:
	if health_regeneration_step != 0.0 and health_regeneration_rate != 0.0:
		set_increase("health", health_regeneration_step, max_health, health_regeneration_rate, delta)

	if mana_regeneration_step != 0.0 and mana_regeneration_rate != 0.0:
		set_increase("mana", mana_regeneration_step, max_mana, mana_regeneration_rate, delta)


func set_increase(name: String, step_value: float, max_value: float, rate: float, delta: float) -> void:
	Utils.change_periodic(self, name, step_value, max_value, rate, delta, Utils.PeriodicTypeID.Increase)


func set_decrease(name: String, step_value: float, max_value: float, rate: float, delta: float) -> void:
	Utils.change_periodic(self, name, step_value, max_value, rate, delta, Utils.PeriodicTypeID.Decrease)
