extends Camera2D

var is_panning:bool = false

var last_mouse:Vector2 = Vector2(0.0,0.0)

var zoom_limit:Vector2 = Vector2(0.2,3.52)

var margin:int = limit_right;

#Seems like get_global_mouse_transform doesn't update immediately after the camera is moved
func custom_get_global_mouse_position(): 
	return transform.affine_inverse().xform(get_viewport().get_mouse_position())


func _unhandled_input(event):
	if event.is_action("pan"):
		is_panning = event.is_action_pressed("pan")
		
	var m:float;
	if event.is_action_pressed("zoom_in"):
		zoom *= 0.9
		m = max(zoom_limit.x, zoom.x)
		zoom = Vector2(m,m)
	if event.is_action_pressed("zoom_out"):
		zoom *= 1.1
		m = min(zoom_limit.y, zoom.x)
		zoom = Vector2(m,m)


func _process(delta):
	scale = Vector2(1.0/zoom.x, 1.0/zoom.y)		
	var ratio = get_viewport().size.x / get_viewport().size.y
	
	limit_top = -margin
	limit_bottom = margin
	limit_left = -margin
	limit_right = margin
	
	if ratio >= 1:
		limit_left = -margin - (margin * (ratio-1) * (zoom.x-zoom_limit[0]) * 0.6)
		limit_right = margin + (margin * (ratio-1) * (zoom.x-zoom_limit[0]) * 0.6)
	else:
		limit_top = -margin - (margin * ((1/ratio)-1) * (zoom.x-zoom_limit[0]) * 0.6)
		limit_bottom = margin + (margin * ((1/ratio)-1) * (zoom.x-zoom_limit[0]) * 0.6)

	var delta_mouse = last_mouse - custom_get_global_mouse_position()
	if is_panning: translate(delta_mouse)
	
	last_mouse = custom_get_global_mouse_position()
