extends CanvasLayer
var game:Node


var fps:Node
var top_label:Node
var buttons:Node
var stats:Node
var minimap:Node
var shop:Node
var controls:Node
var orders:Node
var main_menu:Node
var leaders_icons:Node
var orders_button:Node
var shop_button:Node
var controls_button:Node
var menu_button:Node
var inventories:Node


func _ready():
	game = get_tree().get_current_scene()
	
	fps = get_node("top_left/fps")
	top_label = get_node("top_mid/label")
	shop = get_node("top_right/shop")
	stats = get_node("bot_mid/stats")
	minimap = get_node("bot_left/minimap")
	main_menu = get_node("mid/main_menu")
	buttons = get_node("bot_right/buttons")
	orders = get_node("bot_right/orders")
	controls = get_node("bot_right/controls")
	leaders_icons = get_node("mid_left/leaders_icons")
	
	inventories = stats.get_node("inventories")
	
	controls_button = buttons.get_node("controls_button")
	shop_button = buttons.get_node("shop_button")
	orders_button = buttons.get_node("orders_button")

	buttons.hide()
	main_menu.hide()
	leaders_icons.hide()

	count_time()



func process():
	# if opt.show.fps:
	var f = Engine.get_frames_per_second()
	var n = game.all_units.size()
	fps.set_text('fps: '+str(f)+' u:'+str(n))
	
	if minimap and game.camera.zoom.x <= 1:
		if minimap.update_map_texture: 
			minimap.get_map_texture()
		minimap.move_symbols()
		minimap.follow_camera()



func count_time():
	if not get_tree().paused:
		game.time += 1 
		var array = [game.player_kills, game.player_deaths, game.time, game.enemy_kills, game.enemy_deaths]
		top_label.text ="player: %s/%s - time: %s - enemy: %s/%s" % array
		
	yield(get_tree().create_timer(1), "timeout")
	count_time()



func hide_all():
	for panel in self.get_children():
		panel.hide()


func show_all():
	for panel in self.get_children():
		panel.show()


func hide_all_keep_stats():
	hide_all()
	get_node("bot_mid").show()


func menu_button_down():
	get_tree().paused = true
	game.ui.main_menu.show()
	game.ui.buttons.hide()
	game.ui.leaders_icons.hide()



func shop_button_down():
	shop.visible = !shop.visible
	inventories.update_buttons()
	if shop.visible:
		shop.update_buttons()
		controls.hide()
		orders.hide()
	buttons_update()


func orders_button_down():
	orders.visible = !orders.visible
	if orders.visible:
		shop.hide()
		controls.hide()
		inventories.update_buttons() # hide sell bt
	buttons_update()



func controls_button_down():
	controls.visible = !controls.visible
	if controls.visible:
		shop.hide()
		orders.hide()
		inventories.update_buttons() # hide sell bt
	else: game.control_state = "selection"
	buttons_update()



func show_select():
	stats.update()
	orders_button.disabled = false
	orders.update()


func hide_unselect():
	stats.update()
	controls.hide()
	orders.hide()
	controls_button.disabled = true
	orders_button.disabled = true
	inventories.hide()
	shop.update_buttons()
	buttons_update()



func buttons_update():
	orders_button.set_pressed(orders.visible)
	shop_button.set_pressed(shop.visible)
	controls_button.set_pressed(controls.visible)
