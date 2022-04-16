extends ItemList
var game:Node


func _ready():
	game = get_tree().get_current_scene()

func update():
	game.ui.shop_button.set_pressed(game.ui.shop.visible)
	game.ui.orders_button.set_pressed(game.ui.orders_window.visible)
