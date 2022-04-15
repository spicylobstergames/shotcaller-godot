extends Control
var game:Node

var update_map_texture:bool = true
var is_panning:bool = false
var pan_position:Vector2 = Vector2.ZERO

var map_sprite:Node
var map_tiles:Node
var minimap:Node
var cam_rect:Node
var map_symbols:Node
var map_symbols_map = []


func _ready():
	game = get_tree().get_current_scene()
	map_sprite = game.get_node("map/zoom_out_sprite")
	map_tiles = game.get_node("map/tiles")
	minimap = game.get_node("ui/bot_left/minimap")
	cam_rect = minimap.get_node("cam_rect")
	map_symbols = minimap.get_node("symbols")
	
	hide()
	update_map_texture = true


func _input(event):
	if over_minimap(event):
		# MOUSE CLICK
		if event is InputEventMouseButton:
			is_panning = true
			pan_position = event.position
		
		
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
	return ("position" in event and 
				event.position.x < 150 and 
				event.position.y > get_viewport().size.y - 150)


func get_map_texture():
	game.ui.hide_all()
	for unit in game.all_units: unit.hide()
	yield(get_tree(), "idle_frame")
	var data = game.get_viewport().get_texture().get_data()
	data.flip_y()
	var texture = ImageTexture.new()
	texture.create_from_image(data, 1)
	var minimap_sprite = minimap.get_node("sprite")
	minimap_sprite.set_texture(texture)
	map_sprite.set_texture(texture)
	map_sprite.scale = game.map_camera.zoom
	game.map_camera.current = false
	game.get_node("camera").current = true
	update_map_texture = false
	game.camera.zoom_reset()
	game.ui.show_all()
	for unit in game.all_units: unit.show()
	if not game.started: game.start()


func corner_view():
	map_tiles.visible = true
	minimap.visible = true
	map_sprite.visible = false
	for unit in map_symbols_map:
		unit.get_node("symbol").visible = false
	for unit in game.all_units:
		if unit.has_node("hud"):
			unit.get_node("hud").visible = true
			unit.get_node("sprites").visible = true
			unit.get_node("animations").current_animation = unit.state


func hide_view():
	map_tiles.visible = false
	minimap.visible = false
	map_sprite.visible = true
	for unit in map_symbols_map:
		unit.get_node("symbol").visible = true
	for unit in game.all_units:
		if unit.has_node("hud"):
			unit.get_node("hud").visible = false
			unit.get_node("sprites").visible = false
			unit.get_node("animations").current_animation = ""


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
	var half = game.map.size / 2
	var window_height = get_viewport().size.y
	var pos = Vector2( -half+(pan_position.x * 15), half + ((pan_position.y - window_height) * 15)  )
	if is_panning: game.camera.position = pos
	cam_rect.rect_position = Vector2(50,50) + game.camera.position /15.2
	if cam_rect.rect_position.x < 0: cam_rect.rect_position.x = 0
	if cam_rect.rect_position.x > 100: cam_rect.rect_position.x = 100
	if cam_rect.rect_position.y < 0: cam_rect.rect_position.y = 0
	if cam_rect.rect_position.y > 100: cam_rect.rect_position.y = 100


func move_symbols():
	var symbols = map_symbols.get_children()
	for i in range(symbols.size()):
		var symbol = symbols[i]
		symbol.position = Vector2(2,-148) + map_symbols_map[i].global_position/14.5
