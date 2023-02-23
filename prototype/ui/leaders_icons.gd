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
		buttons_name[leader.name] = button
		button.hpbar.show()
		button.name = leader.name
		index += 1
		button.hint.text = str(index)
		if game.player_team == "blue": button.sprite.material = null
		button.prepare(leader.display_name)
		button.show()
	self.built = true
	self.show()


func buttons_focus(leader):
	buttons_unfocus()
	buttons_name[leader.name].pressed = true


func buttons_unfocus():
	for all_leader_name in buttons_name: 
		buttons_name[all_leader_name].pressed = false


func button_down(index):
	var leader = game.player_leaders[index]
	if leader:
		game.camera.global_position = leader.global_position - game.camera.offset
		game.selection.select_unit(leader)
		game.ui.leaders_icons.buttons_focus(leader)
