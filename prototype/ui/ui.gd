extends CanvasLayer
var game:Node

# self = game.ui

var fps:Node
var top_label:Node
var buttons:Node
var stats:Node
var minimap:Node
var rect_layer: Node
var shop:Node
var controls_menu:Node
var orders_menu:Node
var main_menu:Node
var main_menu_background:Node
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
	minimap = get_node("bot_left/minimap_border/minimap")
	rect_layer = get_node("bot_left/minimap_border/rect_layer")
	main_menu = get_node("mid/main_menu")
	main_menu_background = get_node("background/main")
	buttons = get_node("bot_right/buttons")
	orders_menu = get_node("bot_right/orders_menu")
	controls_menu = get_node("bot_right/controls_menu")
	leaders_icons = get_node("mid_left/leaders_icons")
	
	inventories = stats.get_node("inventories")
	
	controls_button = buttons.get_node("controls_button")
	shop_button = buttons.get_node("shop_button")
	orders_button = buttons.get_node("orders_button")

	count_time()



func process():
	# if opt.show.fps:
	var f = Engine.get_frames_per_second()
	var n = game.all_units.size()
	fps.set_text('fps: '+str(f)+' u:'+str(n))
	
	# minimap display update
	if minimap:
		if minimap.update_map_texture:
			minimap.get_map_texture()
		if game.camera.zoom.x <= 1:
			minimap.move_symbols()
			minimap.follow_camera()
	
	# scale vertical main menu background to fit height
	var h = get_viewport().size.y
	var ratio = get_viewport().size.x / h
	if ratio < 1: 
		var s = 1/ratio
		main_menu_background.scale = Vector2(s*1.666,s*1.666)
		main_menu_background.position = Vector2(-528,-300*s)
	else: 
		main_menu_background.scale = Vector2(1.666,1.666)
		main_menu_background.position = Vector2(-528,-300)


func count_time():
	if not get_tree().paused:
		game.time += 1 
		if game.ended:
			top_label.text = game.victory + ' WINS!'
		else:
			var array = [game.player_kills, game.player_deaths, game.time, game.enemy_kills, game.enemy_deaths]
			top_label.text = "player: %s/%s - time: %s - enemy: %s/%s" % array
			
	yield(get_tree().create_timer(1), "timeout")
	count_time()



func hide_all():
	for panel in self.get_children():
		panel.hide()


func show_all():
	for panel in self.get_children():
		panel.show()


func show_select():
	stats.update()
	if game.can_control(game.selected_unit):
		orders_button.disabled = false
	orders_menu.update()
	controls_menu.update()


func hide_unselect():
	stats.update()
	controls_menu.hide()
	orders_menu.hide()
	controls_button.disabled = true
	orders_button.disabled = true
	inventories.hide()
	shop.update_buttons()
	buttons_update()



func buttons_update():
	orders_button.set_pressed(orders_menu.visible)
	shop_button.set_pressed(shop.visible)
	controls_button.set_pressed(controls_menu.visible)
