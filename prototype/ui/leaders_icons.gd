extends VBoxContainer
var game:Node

# self = game.ui.leaders_icons

var built = false
var buttons_name = {}


var button_template:PackedScene = load("res://ui/buttons/order_button.tscn")

func _ready():
	game = get_tree().get_current_scene()
	hide()
	for placeholder in get_children():
		placeholder.hide()

func build():
	var index = 0
	var buttons_array = self.get_children()
	for leader in game.player_leaders:
		var button = buttons_array[index]
		button.hpbar.visible = true
		index += 1
		button.name = leader.name
		buttons_name[leader.name] = button
		var name_label = button.get_node("name")
		name_label.text = leader.display_name
		var hint_label = button.get_node("hint")
		hint_label.text = str(index)
		var sprite = autoload.leaders[leader.display_name]
		var icon = button.get_node("sprite")
		if game.player_team == "blue": icon.material = null
		icon.region_rect.position.x = sprite * 64
		button.visible = true
		button.leader =  leader
	self.built = true
	self.visible = true

