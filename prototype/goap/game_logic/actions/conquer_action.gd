extends "res://goap/goap_system/action_contract.gd"


const conquer_time = 3


func get_class_name() -> String:
	return "ConquerAction"


func conquer_building(unit):
	unit.after_arive = "stop"
	var point = unit.global_position
	point.y -= WorldState.get_state("map").tile_size
	var building = Utils.get_building(point)
	if not unit.agent.get_state("is_stunned") and building:
		var hp = float(Goap.modifiers.get_value(building, "hp"))
		var current_hp = float(building.current_hp)
		var building_full_hp = (current_hp / hp) == 1
		if building.team == "neutral" and building_full_hp:
			unit.channel_start(conquer_time)
			await unit.channeling_timer.timeout
			if unit.agent.get_state("is_channeling"):
				unit.agent.set_state("is_channeling", false)
				unit.agent.set_state("has_player_command", false)
				building.agent.set_state("is_channeling", false)
				building.setup_team(unit.team)
				match building.display_name:
					"camp", "outpost":
						building.attacks = true
					"mine":
						Goap.get_action("MineAction").set_mine_gold(unit.team, 1)
				var game = Goap.get_tree().get_current_scene()
				game.ui.show_select()


func lose_building(building):
	var team = building.team
	match building.display_name:
		"camp":
			if team == WorldState.get_state("player_team"):
				WorldState.set_state("player_extra_unit", "infantry")
			else:
				WorldState.set_state("enemy_extra_unit", "infantry")
			building.attacks = false
		"outpost":
			building.attacks = false
		"mine":
			Goap.get_action("MineAction").set_mine_gold(team, 0)
	building.setup_team("neutral")
	if not WorldState.get_state("map").has_neutral_buildings(team):
		Goap.get_action("TaxesAction").remove_tax(team)
