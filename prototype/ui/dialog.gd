extends Node
var game:Node


# self = game.ui.dialog

func _ready():
	game = get_tree().get_current_scene()


func show_msg(leader, msg):
	$panel/msg.text = msg
	#var sprite = index of leader
	#$panel/portrait/sprite.region_rect.position.x = sprite * 64
	$panel/name.text = leader.name
