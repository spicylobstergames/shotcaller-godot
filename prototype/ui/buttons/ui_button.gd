extends Button
var game:Node


export var value:String

var blue_team_button:Node
var red_team_button:Node
var small_map_button:Node
var large_map_button:Node
var play_button:Node

onready var circle_transition_scene : PackedScene = preload("res://ui/transitions/circle_transition.tscn")
onready var square_transition_scene : PackedScene = preload("res://ui/transitions/square_transition.tscn")


func _ready():
	game = get_tree().get_current_scene()
	yield(get_tree(), "idle_frame")


func button_down():
	match self.value:
		"menu":
			game.pause()
		
		"shop":
			game.ui.shop.visible = !game.ui.shop.visible
			game.ui.inventories.update_buttons()
			if game.ui.shop.visible:
				game.ui.shop.update_buttons()
				game.ui.controls_menu.visible = false
				game.ui.orders_menu.visible = false
			game.ui.buttons_update()
		
		
		"orders":
			game.ui.orders_menu.visible = !game.ui.orders_menu.visible
			if game.ui.orders_menu.visible:
				game.ui.shop.visible = false
				game.ui.controls_menu.visible = false
				game.ui.inventories.update_buttons() # hide sell bt
			game.ui.buttons_update()
		
		
		"controls":
			game.ui.controls_menu.visible = !game.ui.controls_menu.visible
			if game.ui.controls_menu.visible:
				game.ui.shop.visible = false
				game.ui.orders_menu.visible = false
				game.ui.inventories.update_buttons() # hide sell bt
			else: game.control_state = "selection"
			game.ui.buttons_update()

