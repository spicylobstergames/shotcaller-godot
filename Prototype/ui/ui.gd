extends Node2D
var game:Node

var update_map_texture:bool = true

var map_tiles:Node
var minimap:Node
var map_sprite:Node
var fps:Node
var stats:Node
var map_symbols:Node

func _ready():
	game = get_tree().get_current_scene()
	fps = get_node("top_left/fps")
	minimap = get_node("bot_left/minimap")
	map_symbols = get_node("bot_left/minimap/symbols")
	stats = get_node("bot_mid/stats")
	map_tiles = game.get_node("map/tiles")
	map_sprite = game.get_node("map/sprite")
	update_map_texture = true

func update_stats():
	var unit = game.selected_unit
	
	if unit:
		stats.show()
		var name = unit.name
		stats.get_node("name").text = name
	else:
		stats.hide()


func get_map_texture():
	yield(get_tree(), "idle_frame")
	var data = game.get_viewport().get_texture().get_data()
	data.flip_y()
	var texture = ImageTexture.new()
	texture.create_from_image(data, 1)
	var minimap_sprite = minimap.get_node("sprite")
	minimap_sprite.set_texture(texture)
	map_sprite.set_texture(texture)
	map_sprite.scale = game.get_node("map_camera").zoom
	game.get_node("map_camera").current = false
	game.get_node("camera").current = true
	update_map_texture = false
	game.start()


func minimap_default():
	map_tiles.visible = true
	minimap.visible = true
	map_sprite.visible = false
	for unit in game.all_units:
		unit.get_node("symbol").visible = false
		unit.get_node("hud").visible = true
		unit.get_node("sprites").visible = true
		unit.get_node("animations").current_animation = unit.state


func minimap_cover():
	map_tiles.visible = false
	minimap.visible = false
	map_sprite.visible = true
	for unit in game.all_units:
		unit.get_node("symbol").visible = true
		unit.get_node("hud").visible = false
		unit.get_node("sprites").visible = false
		unit.get_node("animations").current_animation = ""



func hide_hpbar():
	for unit in game.all_units:
		if unit != game.selected_unit:
			unit.get_node("hud/hpbar").visible = false


func show_hpbar():
	for unit in game.all_units:
		unit.get_node("hud/state").visible = true


func hide_state():
	for unit in game.all_units:
		if unit != game.selected_unit:
			unit.get_node("hud/state").visible = false


func show_state():
	for unit in game.all_units:
		unit.get_node("hud/hpbar").visible = true
