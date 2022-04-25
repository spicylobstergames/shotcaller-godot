extends Control
var game:Node

# self = game.ui.minimap

var update_map_texture:bool = true
var is_panning:bool = false
var pan_position:Vector2 = Vector2.ZERO

var map_sprite:Node
var map_tiles:Node
var map_fog:Node
var cam_rect:Node
var map_symbols:Node
var map_symbols_map = []


func _ready():
	game = get_tree().get_current_scene()
	
	map_sprite = game.get_node("map/zoom_out_sprite")
	map_tiles = game.get_node("map/tiles")
	map_fog = game.get_node("map/tiles/fog")
	cam_rect = get_node("cam_rect")
	map_symbols = get_node("symbols")
	
	hide()


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
		event.position.x < 150 and 
		event.position.y > get_viewport().size.y - 150
	)


func get_map_texture():
	game.ui.hide_all()
	for unit in game.all_units: unit.hide()
	yield(get_tree(), "idle_frame")
	var data = game.get_viewport().get_texture().get_data()
	data.flip_y()
	var texture = ImageTexture.new()
	texture.create_from_image(data, 1)
	var minimap_sprite = self.get_node("sprite")
	minimap_sprite.set_texture(texture)
	map_sprite.set_texture(texture)
	map_sprite.scale = game.map_camera.zoom
	game.map_camera.current = false
	game.get_node("camera").current = true
	update_map_texture = false
	game.ui.show_all()
	for unit in game.all_units: unit.show()
	if not game.built: game.build()


func corner_view():
	map_sprite.visible = false
	#map_tiles.visible = true
	for tile in map_tiles.get_children(): 
		if not tile == map_fog: tile.show()
	yield(get_tree(), "idle_frame")
	self.visible = true


func hide_view():
	map_sprite.visible = true
	#map_tiles.visible = false
	for tile in map_tiles.get_children(): 
		if not tile == map_fog: tile.hide()
	
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
	if unit.type != "leader" and unit.team == "red":
		symbol.modulate = Color(0.85,0.4,0.4)


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


func follow_camera():
	if self.visible:
		var half = game.map.size / 2
		var window_height = get_viewport().size.y
		var pos = Vector2( -half+(pan_position.x * 15), half + ((pan_position.y - window_height) * 15)  )
		if is_panning: game.camera.position = pos
		cam_rect.rect_position = Vector2(50,50) + game.camera.position / 15.2
		if cam_rect.rect_position.x < 0: cam_rect.rect_position.x = 0
		if cam_rect.rect_position.x > 100: cam_rect.rect_position.x = 100
		if cam_rect.rect_position.y < 0: cam_rect.rect_position.y = 0
		if cam_rect.rect_position.y > 100: cam_rect.rect_position.y = 100


func move_symbols():
	if self.visible:
		var symbols = map_symbols.get_children()
		for i in range(symbols.size()):
			var symbol = symbols[i]
			symbol.position = Vector2(2,-148) + map_symbols_map[i].global_position/14.5
