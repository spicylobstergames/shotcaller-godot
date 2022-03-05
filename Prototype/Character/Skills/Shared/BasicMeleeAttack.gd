extends Skill

var queued_casts = 0
export var damage: float
export var attack_range: float
	
func cast() -> bool:
	var super_result = .cast()
	if super_result:
		var target = agent.targeted_enemy
		if not is_instance_valid(target):
			return super_result
		var target_attributes = target.get_node("Attributes")
		var agent_attributes = agent.get_node("Attributes")
		if target_attributes.primary.unit_team != agent_attributes.primary.unit_team:
			target_attributes.stats.emit_signal("change_property", "health", target_attributes.stats.health - damage, funcref(target, "_on_attributes_stats_changed"))
	return super_result
	


func get_range():
	return attack_range
