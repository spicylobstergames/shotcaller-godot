extends "res://Character/Character.gd"

var target_point = Vector2(0.0,0.0)
var target_point_set = false
var is_available_respawn = false

func _unhandled_input(event):
	if event.is_action_pressed("give_target"):
		target_point = get_global_mouse_position()
		target_point_set = true
