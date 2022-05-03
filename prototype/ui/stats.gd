extends ItemList
var game:Node

# self = game.ui.stats

onready var panel = get_node("panel")
onready var hpbar = panel.get_node("hpbar")
onready var unit_name = panel.get_node("name")
onready var hp = panel.get_node("hp")
onready var regen = panel.get_node("regen")
onready var vision = panel.get_node("vision")
onready var damage = panel.get_node("damage")
onready var att_range = panel.get_node("range")
onready var speed = panel.get_node("speed")
onready var gold = panel.get_node("gold")
onready var gold_sprite = panel.get_node("gold_sprite")
onready var portrait_sprite = panel.get_node("portrait/sprite")

func _ready():
	game = get_tree().get_current_scene()
	hide()



func update():
	var unit = game.selected_unit
	clear_old_hpbar()
	if not unit: hide()
	else:
		show()
		unit_name.text = "%s" % [unit.display_name]
		hp.text = "%s / %s" % [max(unit.current_hp,0), game.unit.modifiers.get_value(unit, "hp")]
		if unit.regen: regen.text = "+%s" % [game.unit.modifiers.get_value(unit, "regen")]
		else: regen.text = ""
		add_new_hpbar(unit)
		damage.text = "Damage: %s" % game.unit.modifiers.get_value(unit, "damage")
		vision.text = "Vision: %s" % game.unit.modifiers.get_value(unit, "vision")
		att_range.text = "Range: %s" % game.unit.modifiers.get_value(unit, "attack_range")
		if unit.moves: speed.text = "Speed: %s" % game.unit.modifiers.get_value(unit, "speed")
		else: speed.text = ""
		set_texture(portrait_sprite, unit.texture)
		if ((unit.team == game.player_team and unit.type == "leader")
				or (unit.team != game.enemy_team and unit.display_name == "mine")):
			gold.text = "%s" % unit.gold
			gold.visible = true
			gold_sprite.visible = true
		else:
			gold.visible = false
			gold_sprite.visible = false




func set_texture(portrait, texture):
	portrait.texture = texture.data
	portrait.region_rect = texture.region
	portrait.material = texture.material
	portrait.scale = texture.scale
	var sx = abs(portrait.scale.x)
	portrait.scale.x = -1 * sx if texture.mirror else sx



func clear_old_hpbar():
	for old_bar in hpbar.get_children():
		hpbar.remove_child(old_bar)
		old_bar.queue_free()


func add_new_hpbar(unit):
	var red = unit.hud.get_node("hpbar/red").duplicate()
	var green = unit.hud.get_node("hpbar/green").duplicate()
	red.scale *= Vector2(11,11)
	green.scale *= Vector2(11,11)
	hpbar.add_child(red)
	hpbar.add_child(green)


func stats_down(event):
	if event is InputEventMouseButton and not event.pressed: 
		game.selection.unselect()
