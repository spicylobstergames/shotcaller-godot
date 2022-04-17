extends ItemList
var game:Node


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
	if unit:
		show()
		unit_name.text = unit.get_name()
		hp.text = "%s / %s" % [max(unit.current_hp,0), unit.hp]
		if unit.regen: regen.text = "+%s" % [unit.regen]
		else: regen.text = ""
		add_new_hpbar(unit)
		damage.text = "Damage: %s" % unit.current_damage
		vision.text = "Vision: %s" % unit.current_vision
		att_range.text = "Range: %s" % unit.attack_hit_radius
		if unit.moves: speed.text = "Speed: %s" % unit.current_speed
		else: speed.text = ""
		var texture = unit.get_texture()
		set_texture(portrait_sprite, texture)
		if unit.type == "leader" and unit.team == game.player_team:
			gold.text = "%s" % unit.get_gold()
			gold_sprite.visible = true
		else:
			gold.text = ""
			gold_sprite.visible = false
	else:
		hide()


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
