extends ItemList
onready var game:Node = get_tree().get_current_scene()

# self = game.ui.minimap

var default_screen := 600

var update_map_texture:bool = false
var is_panning:bool = false
var pan_position:Vector2 = Vector2.ZERO

var map_sprite:Node
var map_tiles:Node

onready var minimap_container:Node = $"%minimap_container"
onready var rect_layer:Node = $"%rect_layer"
onready var cam_rect:Node = $"%cam_rect"
onready var map_symbols:Node = $"%map_symbols"
onready var light_template:Node = $"%light_template"

var map_symbols_map = []

var size:int = 150
var border:int = 4
var sprite_scale:float = 1.0


func _ready():
	minimap_container.hide()

func _input(event):
	if over_minimap(event):
		# MOUSE CLICK
		if event is InputEventMouseButton:
			match event.button_index:
				BUTTON_LEFT: 
					is_panning = true
					pan_position = event.position
					game.camera.is_panning = false
		
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
			
	else:
		game.selection.input(event)
	
	game.camera.input(event)


func over_minimap(event):
	var viewport = get_viewport()
	var screen = viewport.get_size_override()
	return (
		minimap_container.visible and 
		"position" in event and 
		event.position.x < size and 
		event.position.y > screen.y - size
	)


func map_loaded():
	map_sprite = game.map.get_node("zoom_out_sprite")
	map_tiles = game.map.get_node("tiles")
	var r_size = default_screen * size / max(game.map.size.x, game.map.size.y)
	cam_rect.rect_size = Vector2(r_size, r_size)


func get_map_texture():
	# set camera zoom and limits
	game.camera.offset = game.map.mid
	game.camera.zoom_limit = game.map.zoom_limit
	var zoom_out = game.map.zoom_limit.y
	game.camera.zoom =  Vector2(zoom_out, zoom_out)
	game.camera.position = Vector2.ZERO
	# hides units and ui
	map_sprite.hide()
	game.background.hide()
	game.ui.hide_all()
	hide()
	rect_layer.hide()
	game.map.show()
	game.maps.buildings_visibility(false)
	yield(get_tree(), "idle_frame")
	# take snapshop
	var data = game.get_viewport().get_texture().get_data()
	data.flip_y()
	var texture = ImageTexture.new()
	texture.create_from_image(data, 1)
	# set minimap texture
	var minimap_sprite = $"%sprite"
	minimap_sprite.set_texture(texture)
	var w = float(texture.get_width())
	var h = float(texture.get_height())
	var texture_size = min(w, h)
	sprite_scale = float(size) / float(texture_size)
	minimap_sprite.scale = Vector2(sprite_scale, sprite_scale)
	# texture might be a rectangle so region_rect will clip it
	var texture_ratio = w / h
	var h_diff = 0
	var v_diff = 0
	if texture_ratio > 1.0: h_diff = (w - texture_size) / 2
	if texture_ratio < 1.0: v_diff = (h - texture_size) / 2
	minimap_sprite.region_rect.position = Vector2(h_diff+border/sprite_scale, v_diff+border/sprite_scale)
	minimap_sprite.region_rect.size = Vector2((size-border)/sprite_scale, (size-border)/sprite_scale)
	# set zoom out tile replace
	#map_sprite.set_texture(texture)
	#map_sprite.scale = game.camera.zoom
	# reset cam
	game.camera.zoom_reset()
	# reset units and turn ui back on again
	game.ui.show_all()
	minimap_container.show()
	rect_layer.show()
	game.maps.buildings_visibility(true)
	# turn off and callback
	update_map_texture = false
	game.maps.map_loaded()


func corner_view():
	#map_tiles.show()
	for tile in map_tiles.get_children(): tile.show()
	yield(get_tree(), "idle_frame")
	show()
	rect_layer.show()
	game.ui.get_node("bot_left").show()


func hide_view():
	#map_sprite.show()
	#map_tiles.hide()
	for tile in map_tiles.get_children(): tile.hide()
	# avoid input messing up
	yield(get_tree(), "idle_frame")
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
		var view_height = get_viewport().get_size_override().y
		# stick to the bottom (todo: replace with godot viewports)
		minimap_container.offset.y = view_height
		rect_layer.offset.y = view_height
		var half = game.map.mid
		var map_scale = float(max(game.map.size.x, game.map.size.y)) / float(size)
		var pos = Vector2( -half.x+(pan_position.x * map_scale), half.y + ((pan_position.y - view_height) * map_scale)  )
		var offset = (size - cam_rect.rect_size.y) / 2
		if is_panning: game.camera.position = pos
		# update minimap cam rectangle position
		cam_rect.rect_position = Vector2(offset,offset-size) + game.camera.position / map_scale
		cam_rect.rect_position.x = clamp(cam_rect.rect_position.x, 0, offset*2)
		cam_rect.rect_position.y = clamp(cam_rect.rect_position.y, -size, -cam_rect.rect_size.y)



func move_symbols():
	if minimap_container.visible:
		var symbols = map_symbols.get_children()
		for i in range(symbols.size()):
			var symbol = symbols[i]
			symbol.position = map_symbols_map[i].global_position / max(game.map.size.x, game.map.size.y) * size

