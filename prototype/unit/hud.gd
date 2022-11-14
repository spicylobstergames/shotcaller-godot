extends Node2D
var game:Node

# self = Hud

onready var state = get_node("state")
onready var hpbar = get_node("hpbar")
onready var selection = get_node("selection")


func _ready():
	game = get_tree().get_current_scene()


# HPBAR

func hide_hpbars():
	for unit in game.all_units:
		if (unit != game.selected_unit and 
				unit.has_node('hpbar') and
				unit.hud and
				unit.type != "leader" and
				unit.current_hp == Behavior.modifiers.get_value(unit, "hp") ):
					unit.hud.hpbar.visible = false


func show_hpbars():
	for unit in game.all_units:
		if unit.hud: unit.hud.hpbar.visible = true


func update_hpbar(unit):
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
		if game.camera.zoom.x <= 1 and unit.hud:
			var hp = Behavior.modifiers.get_value(unit, "hp")
			unit.hud.hpbar.visible = true
			var scale = float(unit.current_hp) / float(hp)
			if scale < 0: scale = 0
			if scale > 1: scale = 1
			var size = unit.hud.hpbar.get_node("red").region_rect.size.x 
			unit.hud.hpbar.get_node("green").region_rect.size.x = scale * size
			if leader_icon_hpbar:
				leader_icon_hpbar.get_node("green").region_rect.size.x = scale * size
			if unit.type != "leader" and game.camera.zoom.x == 1 and unit.current_hp >= hp:
					unit.hud.hpbar.hide()


# STATE LABEL

func hide_states():
	for unit in game.all_units:
		if unit != game.selected_unit:
			if unit.hud: unit.hud.state.visible = false


func show_states():
	for unit in game.all_units:
		if unit.hud and unit.type == "leader": 
			unit.hud.hpbar.visible = true


# SELECTION

func show_selected(unit):
	unit.hud.state.visible = true
	unit.hud.selection.visible = true
	update_hpbar(unit)
	unit.hud.hpbar.visible = true


func hide_unselect(unit):
	if unit.type != "leader": unit.hud.state.visible = false
	unit.hud.selection.visible = false
	update_hpbar(unit)
