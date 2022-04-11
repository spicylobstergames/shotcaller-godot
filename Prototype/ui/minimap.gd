extends Node2D
var game:Node

var update_map_texture:bool = true

var map_sprite:Node
var map_tiles:Node
var minimap:Node
var map_symbols:Node
var map_symbols_map = []


func _ready():
	game = get_tree().get_current_scene()
	map_sprite = game.get_node("map/zoom_out_sprite")
	map_tiles = game.get_node("map/tiles")
	minimap = game.get_node("ui/bot_left/minimap")
	map_symbols = minimap.get_node("symbols")
	
	hide()
	update_map_texture = true



func get_map_texture():
	game.ui.shop_button.hide()
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
	minimap.show()
	game.ui.fps.show()
	update_map_texture = false
	game.ui.shop_button.show()
	if not game.started:
		game.start()


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
	var symbol = unit.get_node("symbol").duplicate()
	symbol.visible = true
	symbol.scale *= 0.25
	map_symbols_map.append(unit)
	map_symbols.add_child(symbol)


func move_symbols():
	var symbols = map_symbols.get_children()
	for i in range(symbols.size()):
		var symbol = symbols[i]
		symbol.position = Vector2(-18,-152) + map_symbols_map[i].global_position/15
