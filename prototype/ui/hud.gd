extends Node
var game:Node

# self = game.ui.hud

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


# HUD SELECTION


func show_selected(unit):
	unit.hud.state.visible = true
	unit.hud.selection.visible = true
	unit.hud.update_hpbar()
	unit.hud.hpbar.visible = true


func hide_unselect(unit):
	if unit.type != "leader": unit.hud.state.visible = false
	unit.hud.selection.visible = false
	unit.hud.update_hpbar()
