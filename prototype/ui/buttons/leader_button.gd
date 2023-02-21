extends Button
var game:Node

var leader:Node
var hpbar:Node


func _ready():
	game = get_tree().get_current_scene()
	hpbar = get_node("hpbar")


