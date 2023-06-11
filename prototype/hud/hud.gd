extends Node
var game:Node

# self = game.hud

func _ready():
	game = get_tree().get_current_scene()


func hide_hpbars():
	for unit in WorldState.get_state("all_units"):
		if (unit != game.selected_unit and 
				unit.hud and
				unit.type != "leader" and
				unit.current_hp == Behavior.modifiers.get_value(unit, "hp") ):
					unit.hud.hpbar.hide()


func show_hpbars():
	for unit in WorldState.get_state("all_units"):
		if unit.hud: unit.hud.hpbar.show()


