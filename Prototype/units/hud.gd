extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()

	
# HPBAR


func hide_hpbars():
	for unit in game.all_units:
		if (unit != game.selected_unit and 
				unit.has_node("hud") and 
				unit.current_hp == unit.hp):
			unit.get_node("hud/hpbar").visible = false


func show_hpbars():
	for unit in game.all_units:
		if unit.has_node("hud"):
			unit.get_node("hud/state").visible = true


func update_hpbar(unit):
	if unit.current_hp <= 0:
		unit.get_node("hud/hpbar/green").region_rect.size.x = 0
	else:
		if unit.has_node("hud") and game.camera.zoom.x >= 1:
			unit.get_node("hud/hpbar").visible = true
		var scale = float(unit.current_hp) / float(unit.hp)
		if scale < 0: scale = 0
		if scale > 1: scale = 1
		var size = unit.get_node("hud/hpbar/red").region_rect.size.x 
		unit.get_node("hud/hpbar/green").region_rect.size.x = scale * size
		if unit.current_hp >= unit.hp:
			unit.get_node("hud/hpbar").hide()

# STATE LABEL


func hide_states():
	for unit in game.all_units:
		if unit != game.selected_unit and unit.has_node("hud"):
			unit.get_node("hud/state").visible = false


func show_states():
	for unit in game.all_units:
		if unit.has_node("hud"):
			unit.get_node("hud/hpbar").visible = true

