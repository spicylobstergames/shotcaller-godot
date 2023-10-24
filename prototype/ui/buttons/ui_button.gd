extends Button
var game:Node


@export var value:String

var blue_team_button:Node
var red_team_button:Node
var small_map_button:Node
var large_map_button:Node
var play_button:Node


func _ready():
	game = get_tree().get_current_scene()


func button_down():
	match self.value:
		"menu":
			game.pause()
			game.ui.show_pause_menu()
		
		"shop":
			game.ui.shop.visible = !game.ui.shop.visible
			game.ui.inventories.update_buttons()
			if game.ui.shop.visible:
				game.ui.shop.update_buttons()
				game.ui.unit_controls_panel.hide()
				game.ui.orders_panel.hide()
			game.ui.buttons_update()
		
		
		"orders":
			game.ui.orders_panel.visible = !game.ui.orders_panel.visible
			if game.ui.orders_panel.visible:
				game.ui.shop.hide()
				game.ui.unit_controls_panel.hide()
				game.ui.inventories.update_buttons() # hide sell bt
			game.ui.buttons_update()
		
		
		"controls":
			game.ui.unit_controls_panel.visible = !game.ui.unit_controls_panel.visible
			if game.ui.unit_controls_panel.visible:
				game.ui.shop.hide()
				game.ui.orders_panel.hide()
				game.ui.inventories.update_buttons() # hide sell bt
			
			game.ui.buttons_update()

