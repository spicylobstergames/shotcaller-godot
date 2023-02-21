extends CanvasLayer
var game:Node

# self = game.ui

var fps:Node
var top_label:Node
var stats:Node
var minimap:Node
var minimap_container:Node
var rect_layer: Node
var shop:Node
var control_panel:Node
var unit_controls_panel:Node
var orders_panel:Node
var leaders_icons:Node
var scoreboard:Node
var orders_button:Node
var shop_button:Node
var unit_controls_button:Node
var menu_button:Node
var inventories:Node
var active_skills:Node

onready var main_menu = $"%main_menu"
onready var pause_menu = $"%pause_menu"
onready var new_game_menu = $"%new_game_menu"

var timer:Timer

func _ready():
	game = get_tree().get_current_scene()

	fps = get_node("%fps")
	top_label = get_node("%main_label")
	shop = get_node("%shop")
	stats = get_node("%stats")
	minimap_container = get_node("%minimap_container")
	minimap = minimap_container.get_node("minimap")
	rect_layer = minimap_container.get_node("rect_layer")
	orders_panel = get_node("%orders_panel")
	unit_controls_panel = get_node("%unit_controls_panel")
	control_panel = get_node("%control_panel")
	leaders_icons = get_node("%leaders_icons")
	scoreboard = get_node("%score_board")

	inventories = stats.get_node("inventories")

	unit_controls_button = control_panel.get_node("unit_controls_button")
	shop_button = control_panel.get_node("shop_button")
	orders_button = control_panel.get_node("orders_button")
	
	active_skills = stats.get_node("active_skills")
	
	hide_all()


func map_loaded():
	game.ui.buttons_update()
	game.ui.orders_panel.build()


func process():
	# if opt.show.fps:
	var f = Engine.get_frames_per_second()
	var n = game.all_units.size()
	fps.set_text("fps: "+str(f)+" u:"+str(n))
	
	# minimap display update
	if minimap:
		if minimap.update_map_texture:
			minimap.get_map_texture()
		if game.camera.zoom.x <= 1:
			minimap.move_symbols()
			minimap.follow_camera()


func show_mid():
	hide_all()
	hide_menus()
	show()
	get_node("mid").show()


func show_main_menu():
	show_mid()
	main_menu.show()


func show_pause_menu():
	show_mid()
	pause_menu.show()



func hide_menus():
	get_node("mid").hide()
	main_menu.hide()
	pause_menu.hide()
	new_game_menu.hide()



func hide_all():
	minimap.hide()
	rect_layer.hide()
	for panel in self.get_children():
		panel.hide()


func show_all():
	minimap.show()
	rect_layer.show()
	for panel in self.get_children():
		panel.show()


func show_select():
	stats.update()
	if game.can_control(game.selected_unit):
		orders_button.disabled = false
	orders_panel.update()
	unit_controls_panel.update()


func hide_unselect():
	stats.update()
	orders_panel.hide()
	orders_button.disabled = true
	unit_controls_panel.hide()
	unit_controls_button.disabled = true
	inventories.hide()
	shop.update_buttons()
	buttons_update()



func buttons_update():
	orders_button.set_pressed(orders_panel.visible)
	shop_button.set_pressed(shop.visible)
	unit_controls_button.set_pressed(unit_controls_panel.visible)

