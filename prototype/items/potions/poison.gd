extends Node

onready var game = get_tree().get_current_scene()
export var poison_sprite : Texture

func poison_throw(leader, item):
	var enemy_leaders_on_sight = leader.get_enemy_leaders_on_sight(leader)
	var closest_enemy_leader = leader.closest_unit(enemy_leaders_on_sight)
	var poison_timer := Timer.new()
	
	closest_enemy_leader.add_child(poison_timer)
	poison_timer.wait_time = item.duration
# warning-ignore:return_value_discarded
	poison_timer.connect("timeout", self, "poison_remove", [closest_enemy_leader])
	
	if closest_enemy_leader and Behavior.attack.can_hit(leader, closest_enemy_leader):
		poison_timer.start()
		Behavior.modifiers.add(closest_enemy_leader, "speed", "poisoned", item.attributes.speed)
		Behavior.modifiers.add(closest_enemy_leader, "dot", "poisoned", {"attacker": leader, "damage": item.attributes.dot})
	
		closest_enemy_leader.status_effects["poisoned"] = {
			icon = poison_sprite,
			hint = ("Poison, losing %d hp per second.\nMovement speed slowed by %d." %[(item.attributes.dot), abs(item.attributes.speed)])
				}

func poison_remove(closest_enemy_leader):
	Behavior.modifiers.remove(closest_enemy_leader, "dot", "poisoned")
	Behavior.modifiers.remove(closest_enemy_leader, "speed", "poisoned")
	closest_enemy_leader.status_effects.erase("poisoned")
