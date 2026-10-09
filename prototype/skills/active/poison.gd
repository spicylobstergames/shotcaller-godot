extends Node

@export var skill_data: SkillResource


func poison_throw(leader: Unit, item: ItemResource) -> void:
	var enemy_leaders_on_sight: Array = leader.get_units_in_sight({
		"type": "leader",
		"team": leader.opponent_team()
	})
	var target: Unit = leader.closest_unit(enemy_leaders_on_sight)
	if target == null or not leader.agent.can_hit(target):
		return

	var poison_timer := Timer.new()
	poison_timer.wait_time = skill_data.attributes.duration
	poison_timer.one_shot = true
	poison_timer.timeout.connect(_remove_poison.bind(target, poison_timer))
	target.add_child(poison_timer)
	poison_timer.start()

	Modifiers.add(target, "speed", "poisoned", item.attributes.speed)
	Modifiers.add(target, "dot", "poisoned", {
		"attacker": leader,
		"damage": item.attributes.dot
	})
	target.status_effects["poisoned"] = {
		"icon": skill_data.status_effect_icon,
		"hint": skill_data.status_effect_hint % [
			item.attributes.dot,
			abs(item.attributes.speed)
		]
	}


func _remove_poison(target: Unit, poison_timer: Timer) -> void:
	Modifiers.remove(target, "dot", "poisoned")
	Modifiers.remove(target, "speed", "poisoned")
	target.status_effects.erase("poisoned")
	poison_timer.queue_free()
