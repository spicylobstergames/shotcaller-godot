extends ItemList
var game:Node


onready var control_buttons = get_node("scroll_container/container/move_buttons")

onready var teleport_button = control_buttons.get_node("scroll_container/container/move_buttons")
onready var lane_button = control_buttons.get_node("scroll_container/container/move_buttons")
onready var move_button = control_buttons.get_node("scroll_container/container/move_buttons")
onready var attack_button = control_buttons.get_node("scroll_container/container/move_buttons")


func _ready():
	game = get_tree().get_current_scene()
	hide()



func teleport_button_down():
	buttons_update()


func lane_button_down():
	buttons_update()


func move_button_down():
	buttons_update()


func attack_button_down():
	buttons_update()


func buttons_update():
	if game.selected_unit.type != "leader":
		teleport_button.disabled = true
		lane_button.disabled = true
