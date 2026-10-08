extends "res://goap/goap_system/action_contract.gd"


const pray_time = 10
const pray_cooldown = 60
const _pray_bonuses = [
	["regen", 1],
	["defense", 2],
	["hp", 10]
]


func get_class_name() -> String:
	return "PrayerAction"


func pray_in_church(unit):
	unit.after_arive = "stop"
	var point = unit.global_position
	point.y -= WorldState.get_state("map").tile_size
	var building = Utils.get_building(point)
	if (
		building and building.team == unit.team
		and building.display_name == "church"
		and not building.agent.get_state("is_channeling")
		and not unit.agent.get_state("is_stunned")
	):
		building.agent.set_state("is_channeling", true)
		unit.channel_start(pray_time)
		await unit.channeling_timer.timeout
		if unit.agent.get_state("is_channeling"):
			unit.agent.set_state("is_channeling", false)
			unit.agent.set_state("has_player_command", false)
			pray(unit)
			var game = Goap.get_tree().get_current_scene()
			game.ui.show_select()
			await Goap.get_tree().create_timer(pray_cooldown).timeout
			building.agent.set_state("is_channeling", false)


func pray(unit):
	var random_bonus = _pray_bonuses[randi() % _pray_bonuses.size()]
	Goap.modifiers.add(unit, random_bonus[0], "pray", random_bonus[1])
