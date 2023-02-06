extends Button
var game:Node

var leader:Node
var hpbar:Node

func _ready():
	game = get_tree().get_current_scene()
	hpbar = get_node("hpbar")

func button_down():
	if leader:
		game.camera.global_position = leader.global_position - game.camera.offset
		game.selection.select_unit(leader)
		self.pressed = true

