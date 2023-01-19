extends Node2D
var game:Node

onready var state = get_node("state")
onready var hpbar = get_node("hpbar")
onready var selection = get_node("selection")


# self = unit.hud

func ready():
	game = get_tree().get_current_scene()



# STATE LABEL

func hide_states():
	for unit in game.all_units:
		if unit != game.selected_unit:
			if unit.hud: unit.hud.state.visible = false


func show_states():
	for unit in game.all_units:
		if unit.hud and unit.type == "leader": 
			unit.hud.hpbar.visible = true

