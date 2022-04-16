extends CanvasLayer
var game:Node


var fps:Node
var stats:Node
var minimap:Node
var shop_window:Node
var orders_window:Node
var control_window:Node
var main_menu:Node
var orders_button:Node
var shop_button:Node
var control_button:Node
var menu_button:Node
var inventories:Node


func _ready():
	game = get_tree().get_current_scene()
	fps = get_node("top_mid/fps")
	stats = get_node("bot_mid/stats")
	minimap = get_node("bot_left/minimap")
	main_menu = get_node("mid/main_menu")
	control_button = get_node("bot_right/buttons/control_button")
	shop_button = get_node("bot_right/buttons/shop_button")
	orders_button = get_node("bot_right/buttons/orders_button")
	shop_window = get_node("top_right/shop")
	orders_window = get_node("bot_right/orders")
	inventories = get_node("top_right/inventory/inventories")



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

