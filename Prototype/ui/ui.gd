extends CanvasLayer
var game:Node


var fps:Node
var buttons:Node
var stats:Node
var minimap:Node
var shop:Node
var main_menu:Node
var orders_button:Node
var shop_button:Node
var move_button:Node
var menu_button:Node
var inventories:Node
var orders_window:Node
var move_window:Node


func _ready():
	game = get_tree().get_current_scene()
	
	fps = get_node("top_mid/fps")
	shop = get_node("top_right/shop")
	stats = get_node("bot_mid/stats")
	minimap = get_node("bot_left/minimap")
	main_menu = get_node("mid/main_menu")
	buttons = get_node("bot_right/buttons")
	orders_window = get_node("bot_right/orders")
	move_window = get_node("bot_right/move_control")
	
	inventories = stats.get_node("inventories")
	move_button = buttons.get_node("move_button")
	shop_button = buttons.get_node("shop_button")
	orders_button = buttons.get_node("orders_button")



func process():
	# if opt.show.fps:
	var f = Engine.get_frames_per_second()
	var n = game.all_units.size()
	fps.set_text('fps: '+str(f)+' u:'+str(n))
	
	if minimap and game.camera.zoom.x <= 1:
		if minimap.update_map_texture: minimap.get_map_texture()
		minimap.move_symbols()
		minimap.follow_camera()


func hide_all():
	for panel in self.get_children():
		panel.hide()


func show_all():
	for panel in self.get_children():
		panel.show()



func menu_button_down():
	pass



func shop_button_down():
	shop.visible = !shop.visible
	inventories.update_buttons()
	if shop.visible:
		shop.update_buttons()
		move_window.hide()
		orders_window.hide()
	buttons_update()


func orders_button_down():
	orders_window.visible = !orders_window.visible
	if orders_window.visible:
		shop.hide()
		move_window.hide()
		inventories.update_buttons() # hide sell bt
	buttons_update()



func move_button_down():
	move_window.visible = !move_window.visible
	if move_window.visible:
		shop.hide()
		orders_window.hide()
		inventories.update_buttons() # hide sell bt
	buttons_update()



func show_select():
	stats.update()
	orders_button.disabled = false
	orders_window.update()


func hide_unselect():
	stats.update()
	move_window.hide()
	orders_window.hide()
	move_button.disabled = true
	orders_button.disabled = true
	inventories.hide()
	shop.update_buttons()
	buttons_update()



func buttons_update():
	orders_button.set_pressed(orders_window.visible)
	shop_button.set_pressed(shop.visible)
	move_button.set_pressed(move_window.visible)
