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
			game.ui.leaders_icons.show()
			game.start()
		
		"blue":
			game.player_team = "blue"
			game.enemy_team = "red"
			self.disabled = true
			red_team_button.disabled = false
		
		"red":
			game.player_team = "red"
			game.enemy_team = "blue"
			self.disabled = true
			blue_team_button.disabled = false
		
		
		"menu":
			get_tree().paused = true
			game.ui.main_menu.show()
			game.ui.buttons.hide()
			game.ui.leaders_icons.hide()
		
		
		"shop":
			game.ui.shop.visible = !game.ui.shop.visible
			game.uiinventories.update_buttons()
			if game.ui.shop.visible:
				game.uishop.update_buttons()
				game.uicontrols.hide()
				game.uiorders.hide()
			game.ui.buttons_update()
		
		
		"orders":
			game.ui.orders.visible = !game.ui.orders.visible
			if game.ui.orders.visible:
				game.ui.shop.hide()
				game.ui.controls.hide()
				game.ui.inventories.update_buttons() # hide sell bt
			game.ui.buttons_update()
