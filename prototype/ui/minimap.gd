extends Control
@onready var game:Node = get_tree().get_current_scene()

# self = game.ui.minimap

var default_screen := 600

var update_map_texture:bool = false
var is_panning:bool = false
var pan_position:Vector2 = Vector2.ZERO

var map_sprite:Node
var map_tiles:Node

@onready var minimap_container:Node = $"%minimap_container"
@onready var rect_layer:Node = $"%rect_layer"
@onready var cam_rect:Node = $"%cam_rect"
@onready var map_symbols:Node = $"%map_symbols"
@onready var light_template:Node = $"%light_template"
@onready var minimap_sprite = $"%sprite"

var map_symbols_map = []

var minimap_size:int = 140
var sprite_scale:float = 1.0
var minimap_border:int = 5

func _ready():
	$minimap_container.hide()


func input(event):
	# MOUSE CLICK
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: 
				is_panning = true
				pan_position = event.position
				Crafty_camera.is_panning = false
	
	# MOUSE PAN
	if event.is_action("pan"):
		is_panning = event.is_action_pressed("pan")
	elif event is InputEventMouseMotion:
		if is_panning: pan_position = event.position
	
	
	# TOUCH PAN
	if event is InputEventScreenTouch:
		is_panning = event.is_pressed()
	elif event is InputEventScreenDrag:
		if is_panning: pan_position = event.position



func over_minimap(event):
	var viewport = get_viewport()
	var screen = viewport.get_visible_rect()
	return (
		minimap_container.visible and 
		"position" in event and 
		event.position.x < minimap_size and 
		event.position.x > 0 and 
		event.position.y > screen.end.y - minimap_size and
		event.position.y < screen.end.y
	)


func process():
	if update_map_texture:
		get_map_texture()
	else:
		move_symbols()
		follow_camera()


func get_map_texture():
	# turn off snapshot
	update_map_texture = false
	# map nodes
	map_sprite = game.map.get_node("zoom_out_sprite")
	map_tiles = game.map.get_node("tiles")
	# set camera zoom and limits
	var r_size = default_screen * minimap_size / max(game.map.size.x, game.map.size.y)
	cam_rect.size = Vector2(r_size, r_size)
	cam_rect.pivot_offset = Vector2(r_size/2, r_size/2)
	# hides units and ui
	map_sprite.hide()
	game.background.hide()
	game.ui.hide_all()
	hide()
	rect_layer.hide()
	game.map.show()
	game.maps.buildings_visibility(false)
	Crafty_camera.map_loaded()
	# after the proper map image is draw
	await RenderingServer.frame_post_draw
	# take snapshop
	var snapshop = game.get_viewport().get_texture().get_image()
	var texture = ImageTexture.create_from_image(snapshop)
	minimap_sprite.set_texture(texture)
	# snapshot width and height
	var w = float(texture.get_width())
	var h = float(texture.get_height())
	# set sprite scale
	var texture_size = min(w, h)
	var minimap_sprite_size = minimap_size
	sprite_scale = float(minimap_sprite_size) / float(texture_size)
	minimap_sprite.scale = Vector2(sprite_scale, sprite_scale)
	# texture might be a rectangle so region_rect will clip it
	var texture_ratio = w / h
	var h_diff = 0
	var v_diff = 0
	if texture_ratio > 1.0: h_diff = (w - texture_size) / 2
	if texture_ratio < 1.0: v_diff = (h - texture_size) / 2
	minimap_sprite.region_rect.position = Vector2(h_diff, v_diff)
	minimap_sprite.region_rect.size = Vector2(minimap_size/sprite_scale, minimap_size/sprite_scale)
	# set map zoom out tile replace
	#map_sprite.set_texture(texture)
	#map_sprite.scale = Crafty_camera.zoom
	# reset camera
	Crafty_camera.zoom_reset()
	# reset units and turn ui back on again
	game.ui.show_all()
	minimap_container.show()
	rect_layer.show()
	game.maps.buildings_visibility(true)
	# game map loaded callback
	game.maps.map_loaded()


func corner_view():
	#map_tiles.show()
	for tile in map_tiles.get_children(): tile.show()
	await get_tree().idle_frame
	show()
	rect_layer.show()
	game.ui.get_node("bot_left").show()


func hide_view():
	#map_sprite.show()
	#map_tiles.hide()
	for tile in map_tiles.get_children(): tile.hide()
	# avoid input messing up
	await get_tree().idle_frame
	minimap_container.hide()
	rect_layer.hide()
	game.ui.get_node("bot_left").hide()


func setup_symbol(unit):
	if unit.has_node("symbol") and not unit.symbol:
		var symbol = unit.get_node("symbol")
		setup_unit_symbol(unit, symbol)
		copy_symbol(unit, symbol)
		unit.symbol = true


func setup_unit_symbol(unit, symbol):
	setup_leader_icon(unit, symbol)
	if unit.type == "building":
		symbol.material = null # show behind fog
	if unit.type != "leader":
		match unit.team:
			"red":
				symbol.modulate = Color(0.85,0.4,0.4)
			"neutral":
				symbol.modulate = Color(0.5,0.5,0.5)


func setup_leader_icon(unit, symbol):
	if unit.type == "leader":
		var icon = symbol.get_node("icon_blue")
		if unit.team == "red": 
			icon = symbol.get_node("icon_red")
			icon.scale.x = -1 * abs(icon.scale.x)
		icon.show();
		icon.material = symbol.material
		icon.light_mask = symbol.light_mask


func copy_symbol(unit, symbol):
	var sym = symbol.duplicate()
	sym.show()
	sym.scale *= 0.25
	if unit.team == game.player_team:
		var light = light_template.duplicate()
		light.show()
		var s = float(unit.vision) * 2 / max(game.map.size.x, game.map.size.y)
		light.scale = Vector2(s,s)
		sym.add_child(light)
	map_symbols_map.append(unit)
	map_symbols.add_child(sym)


func follow_camera():
	if minimap_container.visible and game.map:
		var view_height = get_viewport().size.y
		var half = WorldState.get_state("map_mid")
		var map_scale = float(max(game.map.size.x, game.map.size.y)) / float(minimap_size)
		var pos = Vector2( -half.x+(pan_position.x * map_scale), half.y + ((pan_position.y - view_height) * map_scale) )
		if is_panning: Crafty_camera.position = pos
		# update minimap cam rectangle position
		var offset = (minimap_size - cam_rect.size.y) / 2
		cam_rect.position = Vector2(offset,offset) + Crafty_camera.position / map_scale
		cam_rect.position.x = clamp(cam_rect.position.x, minimap_border, offset*2 + minimap_border)
		cam_rect.position.y = clamp(cam_rect.position.y, minimap_border, offset*2 + minimap_border)


func move_symbols():
	if minimap_container.visible:
		var symbols = map_symbols.get_children()
		for i in range(symbols.size()):
			var symbol = symbols[i]
			symbol.position = Vector2(minimap_border,0) + map_symbols_map[i].global_position / max(game.map.size.x, game.map.size.y) * minimap_size

