extends CanvasLayer
var game:Node


var fps:Node
var stats:Node


func _ready():
	game = get_tree().get_current_scene()
	fps = get_node("top_left/fps")
	stats = get_node("bot_mid/stats")


# STATS


func update_stats():
	var unit = game.selected_unit
	if unit:
		stats.show()
		stats.get_node("name").text = "%s (%s) %s" % [unit.subtype, unit.type, unit.current_hp]
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


# HPBAR


func hide_hpbar():
	for unit in game.all_units:
		if unit != game.selected_unit:
			unit.get_node("hud/hpbar").visible = false


func show_hpbar():
	for unit in game.all_units:
		unit.get_node("hud/state").visible = true

func update_hpbar(unit):
	if unit.current_hp <= 0:
		unit.get_node("hud/hpbar/green").region_rect.size.x = 0
	else:
		var scale = float(unit.current_hp) / float(unit.hp)
		if scale < 0: scale = 0
		if scale > 1: scale = 1
		var size = unit.get_node("hud/hpbar/red").region_rect.size.x 
		unit.get_node("hud/hpbar/green").region_rect.size.x = scale * size


# STATE LABEL


func hide_state():
	for unit in game.all_units:
		if unit != game.selected_unit:
			unit.get_node("hud/state").visible = false


func show_state():
	for unit in game.all_units:
		unit.get_node("hud/hpbar").visible = true

