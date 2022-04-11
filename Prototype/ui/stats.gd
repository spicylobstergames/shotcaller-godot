extends ItemList
var game:Node


func _ready():
	game = get_tree().get_current_scene()
	hide()



func update():
	var unit = game.selected_unit
	if unit:
		show()
		get_node("name").text = "%s (%s)" % [unit.subtype, unit.type]
		get_node("hp").text = "HP: %s" % [unit.hp]
		get_node("damage").text = "Damage: %s" % unit.current_damage
		get_node("vision").text = "Vision: %s" % unit.current_vision
		if unit.moves: get_node("speed").text = "Speed: %s" % unit.current_speed
		else: get_node("speed").text = ""
		var texture = unit.get_texture()
		var portrait = get_node("portrait/sprite")
		set_texture(portrait, texture)
		if unit.type == "leader":
			var gold = str(game.ui.leaders_inventories.inventories[unit.name].gold)
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
