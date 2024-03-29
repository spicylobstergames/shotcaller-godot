extends Node2D

@onready var game = get_tree().get_current_scene()
@onready var unit = get_parent()
@onready var state = get_node("state")
@onready var hpbar = get_node("hpbar")
@onready var selection = get_node("selection")


# self = unit.hud


func update_hpbar():
	if WorldState.get_state("is_game_active"):
		var player_leader = (unit.type == "leader" and unit.team == WorldState.get_state("player_team"))
		var leader_icon_hpbar
		if player_leader and unit.name in game.ui.leaders_icons.buttons_name:
			var leader_icon = game.ui.leaders_icons.buttons_name[unit.name]
			leader_icon_hpbar = leader_icon.get_node("hpbar")
		if unit.current_hp <= 0:
			unit.current_hp = 0
			hpbar.get_node("green").region_rect.size.x = 0
			if leader_icon_hpbar:
				leader_icon_hpbar.get_node("green").region_rect.size.x = 0
		else:
			var hp = Behavior.modifiers.get_value(unit, "hp")
			hpbar.show()
			var h_scale = float(unit.current_hp) / float(hp)
			if h_scale < 0: h_scale = 0
			if h_scale > 1: h_scale = 1
			var size = hpbar.get_node("red").region_rect.size.x 
			hpbar.get_node("green").region_rect.size.x = h_scale * size
			if leader_icon_hpbar:
				leader_icon_hpbar.get_node("green").region_rect.size.x = h_scale * size
			if (unit.type != "leader" 
				and unit.current_hp >= hp 
				and not unit == WorldState.get_state("selected_unit")):
				hpbar.hide()


func show_selected():
	unit.hud.state.show()
	unit.hud.selection.show()
	unit.hud.update_hpbar()
	unit.hud.hpbar.show()
	
	

func hide_unselect():
	if unit.type != "leader" && !WorldState.get_state("hide_leaders_hud"): # opts
		unit.hud.state.hide()
		unit.hud.hpbar.hide()
	unit.hud.selection.hide()



