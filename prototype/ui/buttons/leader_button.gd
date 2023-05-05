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
	name_label.text = leader_name[0].to_upper() + leader_name.substr(1,-1)
	if leader_name == "random":
		sprite.texture = question_mark
	else:
		sprite.texture = leader_icons
		var sprite_index = WorldState.leaders[leader_name]
		var sprites_size = sprite.region_rect.size.x
		sprite.region_rect.position.x = sprite_index * sprites_size
	# button color
	color_remap(new_team)


func color_remap(new_team):
	team = new_team
	if team == "blue":
		sprite.material = null
	else:
		sprite.material = red_material
