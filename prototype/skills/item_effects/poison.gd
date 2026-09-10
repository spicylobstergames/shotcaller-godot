extends Node

const DURATION := 5.0

@export var poison_sprite: Texture2D


func poison_throw(leader: Unit, item: Item_resource) -> void:
	var enemy_leaders_on_sight: Array = leader.get_units_in_sight({
		"type": "leader",
		"team": leader.opponent_team()
	})
	var target: Unit = leader.closest_unit(enemy_leaders_on_sight)
	if target == null or not Behavior.attack.can_hit(leader, target):
		return

	var poison_timer := Timer.new()
	poison_timer.wait_time = DURATION
	poison_timer.one_shot = true
	poison_timer.timeout.connect(_remove_poison.bind(target, poison_timer))
	target.add_child(poison_timer)
	poison_timer.start()

	Behavior.modifiers.add(target, "speed", "poisoned", item.attributes.speed)
	Behavior.modifiers.add(target, "dot", "poisoned", {
		"attacker": leader,
		"damage": item.attributes.dot
	})
	target.status_effects["poisoned"] = {
		"icon": poison_sprite,
		"hint": "Poison, losing %d hp per second.\nMovement speed slowed by %d." % [
			item.attributes.dot,
			abs(item.attributes.speed)
		]
	}


func _remove_poison(target: Unit, poison_timer: Timer) -> void:
	Behavior.modifiers.remove(target, "dot", "poisoned")
	Behavior.modifiers.remove(target, "speed", "poisoned")
	target.status_effects.erase("poisoned")
	poison_timer.queue_free()
