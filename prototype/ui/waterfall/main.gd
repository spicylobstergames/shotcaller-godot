extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	# _capture()
	pass

var current_frame = 0
func _capture():
	get_viewport().set_clear_mode(Viewport.CLEAR_MODE_ONLY_NEXT_FRAME)
	# Wait until the frame has finished before getting the texture.
	yield(VisualServer, "frame_post_draw")

	# Retrieve the captured image.
	var img = get_viewport().get_texture().get_data()

	# Flip it on the y-axis (because it's flipped).
	img.flip_y()
	img.save_png("res://frame-{frame}.png".format({"frame": current_frame}))
	current_frame += 1


func _on_Timer_timeout():
	#_capture()
	pass # Replace with function body.
