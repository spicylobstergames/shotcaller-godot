extends Control
var game:Node

# self = game.ui.unit_controls_panel

@onready var teleport_button = get_node("%teleport_button")
@onready var lane_button = get_node("%lane_button")
@onready var move_button = get_node("%move_button")
@onready var attack_button = get_node("%attack_button")


func _ready():
	game = get_tree().get_current_scene()
	hide()


	#"buiding_defense": ["alarm bell"]


func teleport_button_down():
	if teleport_button.is_pressed(): game.control_state = "teleport"
	buttons_update(teleport_button)


func lane_button_down():
	if lane_button.is_pressed(): game.control_state = "lane"
	else: game.control_state = "selection"
	buttons_update(lane_button)


func move_button_down():
	if move_button.is_pressed(): game.control_state = "move"
	else: game.control_state = "selection"
	buttons_update(move_button)



func attack_button_down():
	if attack_button.is_pressed(): game.control_state = "advance"
	else: game.control_state = "selection"
	buttons_update(attack_button)



func buttons_update(button):
	clear_siblings(button)


func clear_siblings(button):
	var counter = 0
	for child in button.get_parent().get_children():
		counter += 1
		if child != button and counter > 1: 
			child.button_pressed = false
			child.disabled = false
