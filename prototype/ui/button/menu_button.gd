extends Button
var game:Node



export var value:String

var blue_team_button
var red_team_button

func _ready():
	game = get_tree().get_current_scene()
	yield(get_tree(), "idle_frame")
	
	var buttons = game.ui.main_menu.get_node("container/menu_team_buttons")
	blue_team_button = buttons.get_node("blue_team_button")
	red_team_button = buttons.get_node("red_team_button")


func button_down():
	match self.value:
		
		"play":
			get_tree().paused = false
			game.ui.main_menu.hide()
			game.ui.buttons.show()
			game.start()
		
		"blue":
			game.player_team = "blue"
			game.enemy_team = "red"
			red_team_button.pressed = false
			red_team_button.disabled = false
			blue_team_button.disabled = true
		
		"red":
			game.player_team = "red"
			game.enemy_team = "blue"
			blue_team_button.pressed = false
			blue_team_button.disabled = false
			red_team_button.disabled = true
		
		
		"menu":
			get_tree().paused = true
			game.ui.main_menu.show()
			game.ui.buttons.hide()
			game.ui.leaders_icons.hide()
		
		
		"shop":
			game.ui.shop.visible = !game.ui.shop.visible
			game.ui.inventories.update_buttons()
			if game.ui.shop.visible:
				game.ui.shop.update_buttons()
				game.ui.controls.hide()
				game.ui.orders.hide()
			game.ui.buttons_update()
		
		
		"orders":
			game.ui.orders.visible = !game.ui.orders.visible
			if game.ui.orders.visible:
				game.ui.shop.hide()
				game.ui.controls.hide()
				game.ui.inventories.update_buttons() # hide sell bt
			game.ui.buttons_update()
		
		"controls":
			game.ui.controls.visible = !game.ui.controls.visible
			if game.ui.controls.visible:
				game.ui.shop.hide()
				game.ui.orders.hide()
				game.ui.inventories.update_buttons() # hide sell bt
			else: game.control_state = "selection"
			game.ui.buttons_update()
