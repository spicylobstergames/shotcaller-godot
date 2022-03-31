extends CanvasLayer
var game:Node

var update_map_texture:bool = true

var map_tiles:Node
var minimap:Node
var map_sprite:Node
var fps:Node
var stats:Node
var map_symbols:Node
var map_symbols_map = []


func _ready():
	game = get_tree().get_current_scene()
	fps = get_node("top_left/fps")
	minimap = get_node("bot_left/minimap")
	map_symbols = get_node("bot_left/minimap/symbols")
	stats = get_node("bot_mid/stats")
	map_tiles = game.get_node("map/tiles")
	map_sprite = game.get_node("map/sprite")
	update_map_texture = true


# STATS


func update_stats():
	var unit = game.selected_unit
	if unit:
		stats.show()
		stats.get_node("name").text = "%s (%s)" % [unit.subtype, unit.type]
		stats.get_node("damage").text = "Damage: %s" % unit.current_damage
		stats.get_node("vision").text = "Vision: %s" % unit.current_vision
		if unit.moves: stats.get_node("speed").text = "Speed: %s" % unit.current_speed
		else: stats.get_node("speed").text = ""
		var texture = unit.get_texture()
		stats.get_node("portrait/sprite").texture = texture.data
		stats.get_node("portrait/sprite").region_rect = texture.region
		stats.get_node("portrait/sprite").scale = texture.scale
	else:
		stats.hide()


# MINIMAP


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
	minimap.show()
	update_map_texture = false
	game.start()


func minimap_default():
	map_tiles.visible = true
	minimap.visible = true
	map_sprite.visible = false
	for unit in map_symbols_map:
		unit.get_node("symbol").visible = false
	for unit in game.all_units:
		unit.get_node("hud").visible = true
		unit.get_node("sprites").visible = true
		unit.get_node("animations").current_animation = unit.state


func minimap_cover():
	map_tiles.visible = false
	minimap.visible = false
	map_sprite.visible = true
	for unit in map_symbols_map:
		unit.get_node("symbol").visible = true
	for unit in game.all_units:
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


# HPBAR


func hide_hpbar():
	for unit in game.all_units:
		if unit != game.selected_unit:
			unit.get_node("hud/hpbar").visible = false


func show_hpbar():
	for unit in game.all_units:
		unit.get_node("hud/state").visible = true


# STATE LABEL


func hide_state():
	for unit in game.all_units:
		if unit != game.selected_unit:
			unit.get_node("hud/state").visible = false


func show_state():
	for unit in game.all_units:
		unit.get_node("hud/hpbar").visible = true

