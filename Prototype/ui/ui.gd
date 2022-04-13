extends CanvasLayer
var game:Node


var fps:Node
var stats:Node
var minimap:Node
var shop_button:Node
var shop_window:Node
var leaders_inventories:Node
var orders_container:Node


func _ready():
	game = get_tree().get_current_scene()
	fps = get_node("top_left/fps")
	stats = get_node("bot_mid/stats")
	minimap = get_node("bot_left/minimap")
	shop_button = get_node("top_right/shop_button")
	shop_window = get_node("top_right/shop_window")
	leaders_inventories = get_node("bot_right/leaders_inventories")
	orders_container = get_node("bot_right/orders_container")



func process():
	# if opt.show.fps:
	var f = Engine.get_frames_per_second()
	var n = game.all_units.size()
	fps.set_text('fps: '+str(f)+' u:'+str(n))
	
	if minimap and game.camera.zoom.x <= 1:
		if minimap.update_map_texture: minimap.get_map_texture()
		minimap.move_symbols()
		minimap.follow_camera()

