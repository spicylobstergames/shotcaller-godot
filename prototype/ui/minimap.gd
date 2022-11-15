extends CanvasLayer
var game:Node

# self = game.ui.minimap

var update_map_texture:bool = false
var is_panning:bool = false
var pan_position:Vector2 = Vector2.ZERO

var map_sprite:Node
var map_tiles:Node
var cam_rect:Node
var map_symbols:Node
var map_symbols_map = []

var size:int = 150
var border:int = 4
var sprite_scale:float = 1.0

func _ready():
	game = get_tree().get_current_scene()
	cam_rect = get_parent().get_node("rect_layer/cam_rect")
	map_symbols = get_node("symbols")



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


func over_minimap(event):
	return (
		self.get_parent().visible and
		self.visible and 
		"position" in event and 
		event.position.x < size and 
		event.position.y > get_viewport().size.y - size
	)

func map_loaded():
	map_sprite = game.map.get_node("zoom_out_sprite")
	map_tiles = game.map.get_node("tiles")
	game.ui.minimap.update_map_texture = true


func get_map_texture():
	# set camera zoom and limits
	game.camera.offset = game.map.mid
	game.camera.zoom_limit = game.map.zoom_limit
	var zoom_out = game.map.zoom_limit.y
	game.camera.zoom =  Vector2(zoom_out, zoom_out)
	# hides units and ui
	game.ui.hide_all()
	self.visible = false
	game.ui.rect_layer.visible = false
	game.maps.buildings_visibility(false)
	yield(get_tree(), "idle_frame")
	# take snapshop
	var data = game.get_viewport().get_texture().get_data()
	data.flip_y()
	var texture = ImageTexture.new()
	texture.create_from_image(data, 1)
	# set minimap texture
	var minimap_sprite = self.get_node("sprite")
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
	map_sprite.set_texture(texture)
	map_sprite.scale = game.camera.zoom
	# reset cam
	game.camera.zoom_reset()
	# reset units and ui back again
	game.ui.show_all()
	self.visible = true
	game.ui.rect_layer.visible = true
	game.maps.buildings_visibility(true)
	# turn off and callback
	update_map_texture = false
	game.maps.map_loaded()


func corner_view():
	map_sprite.visible = false
	#map_tiles.visible = true
	for tile in map_tiles.get_children(): tile.show()
	yield(get_tree(), "idle_frame")
	self.visible = true
	game.ui.rect_layer.visible = true
	game.ui.get_node("bot_left").visible = true


func hide_view():
	map_sprite.visible = true
	#map_tiles.visible = false
	for tile in map_tiles.get_children(): tile.hide()
	# avoid input messing up
	yield(get_tree(), "idle_frame")
	self.visible = false
	game.ui.rect_layer.visible = false
	game.ui.get_node("bot_left").visible = false


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
		icon.visible = true;
		icon.material = symbol.material
		icon.light_mask = symbol.light_mask


func copy_symbol(unit, symbol):
	var sym = symbol.duplicate()
	sym.visible = true
	sym.scale *= 0.25
	if unit.team == game.player_team:
		var light = get_node("light_template").duplicate()
		light.visible = true
		var s = float(unit.vision) * 2 / (game.map.size)
		light.scale = Vector2(s,s)
		sym.add_child(light)
	map_symbols_map.append(unit)
	map_symbols.add_child(sym)


func follow_camera():
	var window_height = get_viewport().size.y
	var view_height = get_viewport().get_size_override().y
	self.offset.y = view_height
	game.ui.rect_layer.offset.y = view_height
	if self.visible:
		var half = game.map.size / 2
		var s = float(game.map.size) / float(size)
		var pos = Vector2( -half+(pan_position.x * s), half + ((pan_position.y - window_height) * s)  )
		var offset = (size - cam_rect.rect_size.y) / 2
		if is_panning: game.camera.position = pos
		cam_rect.rect_position = Vector2(offset,offset-size) + game.camera.position / s
		if cam_rect.rect_position.x < 0: cam_rect.rect_position.x = 0
		if cam_rect.rect_position.x > offset*2: cam_rect.rect_position.x = offset*2
		if cam_rect.rect_position.y < -size: cam_rect.rect_position.y = -size
		if cam_rect.rect_position.y > -cam_rect.rect_size.y: cam_rect.rect_position.y = -cam_rect.rect_size.y


func move_symbols():
	if self.visible:
		var symbols = map_symbols.get_children()
		for i in range(symbols.size()):
			var symbol = symbols[i]
			symbol.position = map_symbols_map[i].global_position / game.map.size * size

