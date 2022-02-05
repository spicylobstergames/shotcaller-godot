extends Camera2D

var is_panning = false

var last_mouse = Vector2(0.0,0.0)


#Seems like get_global_mouse_transform doesn't update immediately after the camera is moved
func custom_get_global_mouse_position(): 
	return transform.affine_inverse().xform(get_viewport().get_mouse_position())

func _unhandled_input(event):
	if event.is_action("pan"):
		is_panning = event.is_action_pressed("pan")
	if event.is_action_pressed("zoom_in"):
		zoom *= 0.9
	if event.is_action_pressed("zoom_out"):
		zoom *= 1.1
func _process(delta):
	scale = Vector2(1.0/zoom.x, 1.0/zoom.y)
	var delta_mouse = last_mouse - custom_get_global_mouse_position()
	
	if is_panning:
		translate(delta_mouse)

	last_mouse = custom_get_global_mouse_position()
