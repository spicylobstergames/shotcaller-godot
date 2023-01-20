extends Node2D
var game:Node

onready var unit = get_parent()
onready var state = get_node("state")
onready var hpbar = get_node("hpbar")
onready var selection = get_node("selection")

# self = unit.hud

func ready():
	game = get_tree().get_current_scene()


func update_hpbar():
	if game and game.started and not game.paused:
		var player_leader = (unit.type == 'leader' and unit.team == game.player_team)
		var leader_icon_hpbar
		if player_leader and unit.name in game.ui.leaders_icons.buttons_name:
			leader_icon_hpbar = game.ui.leaders_icons.buttons_name[unit.name].hpbar
		if unit.current_hp <= 0:
			unit.current_hp = 0
			unit.hud.hpbar.get_node("green").region_rect.size.x = 0
			if leader_icon_hpbar:
				leader_icon_hpbar.get_node("green").region_rect.size.x = 0
		else:
			var hp = Behavior.modifiers.get_value(unit, "hp")
			unit.hud.hpbar.visible = true
			var scale = float(unit.current_hp) / float(hp)
			if scale < 0: scale = 0
			if scale > 1: scale = 1
			var size = unit.hud.hpbar.get_node("red").region_rect.size.x 
			unit.hud.hpbar.get_node("green").region_rect.size.x = scale * size
			if leader_icon_hpbar:
				leader_icon_hpbar.get_node("green").region_rect.size.x = scale * size
			if unit.type != "leader" and unit.current_hp >= hp:
					unit.hud.hpbar.hide()

# STATE LABEL

func hide_states():
	for unit1 in game.all_units:
		if unit1 != game.selected_unit:
			if unit1.hud: unit1.hud.state.visible = false


func show_states():
	for unit1 in game.all_units:
		if unit1.hud and unit1.type == "leader": 
			unit1.hud.hpbar.visible = true

