extends Control
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
var scale:float = 1.0

func _ready():
	game = get_tree().get_current_scene()
	
	cam_rect = get_node("cam_rect")
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

func start():
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
	for unit in game.all_units: unit.hide()
	yield(get_tree(), "idle_frame")
	# take snapshop
	var data = game.get_viewport().get_texture().get_data()
	data.flip_y()
	var texture = ImageTexture.new()
	texture.create_from_image(data, 1)
	# set minimap texture
	var minimap_sprite = self.get_node("sprite")
	minimap_sprite.set_texture(texture)
	scale = 0.96 * float(size) / float(texture.get_height())
	minimap_sprite.scale = Vector2(scale, scale)
	# set zoom out tile replace
	map_sprite.set_texture(texture)
	map_sprite.scale = game.camera.zoom
	# reset cam
	game.camera.zoom_reset()
	# reset units and ui back again
	game.ui.show_all()
	for unit in game.all_units: unit.show()
	# turn off and callback
	update_map_texture = false
	game.maps.map_loaded()


func corner_view():
	map_sprite.visible = false
	#map_tiles.visible = true
	for tile in map_tiles.get_children(): tile.show()
	yield(get_tree(), "idle_frame")
	self.visible = true


func hide_view():
	map_sprite.visible = true
	#map_tiles.visible = false
	for tile in map_tiles.get_children(): tile.hide()
	
	# avoid input messing up
	yield(get_tree(), "idle_frame")
	self.visible = false


func setup_symbol(unit):
	if unit.has_node("symbol"):
		var symbol = unit.get_node("symbol")
		setup_unit_symbol(unit, symbol)
		copy_symbol(unit, symbol)

func setup_unit_symbol(unit, symbol):
	setup_leader_icon(unit, symbol)
	if unit.type != "leader":
		match unit.team:
			"red":
				symbol.modulate = Color(0.85,0.4,0.4)
			"neutral":
				symbol.modulate = Color(0.5,0.5,0.5)

func setup_leader_icon(unit, symbol):
	if symbol.has_node("icon") and unit.type == "leader":
		var icon = symbol.get_node("icon")
		if unit.team == "blue": icon.material = null
		else: icon.scale.x = -1 * abs(icon.scale.x)


func copy_symbol(unit, symbol):
	var copy = symbol.duplicate()
	copy.visible = true
	copy.scale *= 0.25
	map_symbols_map.append(unit)
	map_symbols.add_child(copy)


	# minimap size 150~
	# texture size 600~~
	# map size 1056
	# scale .25
	
func follow_camera():
	if self.visible:
		var half = game.map.size / 2
		var window_height = get_viewport().size.y
		var pos = Vector2( -half+(pan_position.x * 15), half + ((pan_position.y - window_height) * 15)  )
		var offset = 53
		if is_panning: game.camera.position = pos
		cam_rect.rect_position = Vector2(offset,offset) + game.camera.position / 13.5
		if cam_rect.rect_position.x < 0: cam_rect.rect_position.x = 0
		if cam_rect.rect_position.x > offset*2: cam_rect.rect_position.x = offset*2
		if cam_rect.rect_position.y < 0: cam_rect.rect_position.y = 0
		if cam_rect.rect_position.y > offset*2: cam_rect.rect_position.y = offset*2


func move_symbols():
	if self.visible:
		var symbols = map_symbols.get_children()
		for i in range(symbols.size()):
			var symbol = symbols[i]
			symbol.position = Vector2(0,-size) + map_symbols_map[i].global_position/14.5
