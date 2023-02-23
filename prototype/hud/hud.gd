extends Node
var game:Node

# self = game.hud

func _ready():
	game = get_tree().get_current_scene()


# HPBAR


func hide_hpbars():
	for unit in game.all_units:
		if (unit != game.selected_unit and 
				unit.has_node("hpbar") and
				unit.hud and
				unit.type != "leader" and
				unit.current_hp == Behavior.modifiers.get_value(unit, "hp") ):
					unit.hud.hpbar.hide()


func show_hpbars():
	for unit in game.all_units:
		if unit.hud: unit.hud.hpbar.show()


# HUD SELECTION


func show_selected(unit):
	unit.hud.state.show()
	unit.hud.selection.show()
	unit.hud.update_hpbar()
	unit.hud.hpbar.show()


func hide_unselect(unit):
	if unit.type != "leader": unit.hud.state.hide()
	unit.hud.selection.hide()
	unit.hud.update_hpbar()
