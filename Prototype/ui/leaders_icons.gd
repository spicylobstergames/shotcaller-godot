extends VBoxContainer
var game:Node


var clear = false


var buttons = {}
var button_template:PackedScene = load("res://controls/orders/button/order_button.tscn")


func _ready():
	game = get_tree().get_current_scene()

	hide()

	if not clear:
		for placeholder in self.get_children():
			self.remove_child(placeholder)
			placeholder.queue_free()
		
		clear = true


func build():
	var index = 0
	for leader in game.player_leaders:
		index += 1
		var button = button_template.instance()
		buttons[leader.name] = button
		self.add_child(button)
		button.name_label.text = leader.display_name
		button.hint_label.text = str(index)
		var texture = leader.get_texture().data
		button.icon = texture
		button.orders = {
			"type": "leader",
			"leader": leader
		}
	show()

func button_down(leader):
	game.camera.global_position = leader.global_position - game.camera.offset
	game.selection.select_unit(leader)
