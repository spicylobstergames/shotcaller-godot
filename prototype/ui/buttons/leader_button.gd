extends Button

class_name Leader_button

var leader:Node
var leader_name:String
var team:String = "red"

var sprite:Node
var name_label:Node
var hpbar:Node
var hint:Node

var question_mark = preload("res://assets/ui/question_mark.png")
var leader_icons = preload("res://assets/ui/leaders_icons.png")

var red_material

func _ready():
	sprite = get_node("sprite")
	name_label = get_node("name_label")
	hint = get_node("hint")
	hpbar = get_node("hpbar")
	
	red_material = sprite.material


func prepare(new_leader_name, new_team = "red"):
	# leader sprite
	leader_name = new_leader_name
	name_label.text = Utils.first_to_uppper(leader_name)
	if leader_name == "random":
		sprite.texture = question_mark
	else:
		sprite.texture = leader_icons
		var sprite_index = WorldState.leaders_list[leader_name]
		var sprites_size = sprite.region_rect.size.x
		sprite.region_rect.position.x = sprite_index * sprites_size
	# button color
	color_remap(new_team)
	# shortcuts
	var keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	# avoid out of index error!
	if get_index() >= keys.size():
		return
	var sc := Shortcut.new()
	var ev := InputEventKey.new()
	ev.keycode = keys[get_index()]
	sc.events.append(ev)
	shortcut = sc


func color_remap(new_team):
	team = new_team
	if team == "blue":
		sprite.material = null
	else:
		sprite.material = red_material
