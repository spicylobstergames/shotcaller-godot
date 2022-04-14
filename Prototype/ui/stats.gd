extends ItemList
var game:Node


func _ready():
	game = get_tree().get_current_scene()
	hide()



func update():
	var unit = game.selected_unit
	if unit:
		show()
		
		get_node("name").text = unit.get_name()
		get_node("hp").text = "HP: %s" % [unit.current_hp]
		get_node("damage").text = "Damage: %s" % unit.current_damage
		get_node("vision").text = "Vision: %s" % unit.current_vision
		get_node("range").text = "Range: %s" % unit.attack_hit_radius
		if unit.moves: get_node("speed").text = "Speed: %s" % unit.current_speed
		else: get_node("speed").text = ""
		var texture = unit.get_texture()
		var portrait = get_node("portrait/sprite")
		set_texture(portrait, texture)
		if unit.type == "leader" and unit.team == game.player_team:
			var gold = str(game.ui.inventories.leaders[unit.name].gold)
			get_node("gold").text = "Gold: %s" % gold
		else:
			get_node("gold").text = ""
	else:
		hide()

func set_texture(portrait, texture):
	portrait.texture = texture.data
	portrait.region_rect = texture.region
	portrait.material = texture.material
	portrait.scale = texture.scale
	var sx = abs(portrait.scale.x)
	portrait.scale.x = -1 * sx if texture.mirror else sx


func _on_stats_gui_input(event):
	if event is InputEventMouseButton and not event.pressed: 
		game.controls.unselect()
