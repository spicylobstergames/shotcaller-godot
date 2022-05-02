extends Button
var game:Node

var leader:Node


func _ready():
	game = get_tree().get_current_scene()


func button_down():
	if leader:
		game.camera.global_position = leader.global_position - game.camera.offset
		game.selection.select_unit(leader)
		self.pressed = true

