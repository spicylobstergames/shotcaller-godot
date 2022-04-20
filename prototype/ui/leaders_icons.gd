extends VBoxContainer
var game:Node


var buttons_name = {}

var button_template:PackedScene = load("res://controls/orders/button/order_button.tscn")
var sprites_order = ["arthur","bokuden","hongi","lorne","nagato","osman","raja","robin","rollo","sida","takoda","tomyris"]

func _ready():
	game = get_tree().get_current_scene()
	
	hide()



func build():
	var index = 0
	var buttons_array = self.get_children()
	for leader in game.player_leaders:
		var button = buttons_array[index]
		index += 1
		button.name = leader.name
		buttons_name[leader.name] = button
		var name_label = button.get_node("name")
		name_label.text = leader.display_name
		var hint_label = button.get_node("hint")
		hint_label.text = str(index)
		var sprite = sprites_order.find(leader.display_name)
		var icon = button.get_node("sprite")
		icon.region_rect.position.x = sprite * 96
		if game.player_team == "red":
			var material = game.unit.get_node("sprites/sprite").material
			print(material)
			icon.material = material
		button.leader =  leader
	show()


