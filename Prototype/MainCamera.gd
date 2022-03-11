extends Camera2D

var is_panning:bool = false

var relative_position:Vector2 = Vector2(0.0,0.0)

var zoom_limit:Vector2 = Vector2(0.32,3.52)
var margin:int = limit_right;
	
func _unhandled_input(event):
	# touch
	if event is InputEventScreenTouch:
		is_panning = event.is_pressed()
	elif event is InputEventScreenDrag:
		if is_panning: relative_position = Vector2(-1 * event.relative)
	# mouse
	if event.is_action("pan"):
		is_panning = event.is_action_pressed("pan")
	elif event is InputEventMouseMotion:
		if is_panning: relative_position = Vector2(-1 * event.relative)
	# zoom
	if event.is_action_pressed("zoom_in"):
		if zoom.x == zoom_limit.y:
			zoom = Vector2(1,1)
		elif zoom.x == 1:
			zoom = Vector2(zoom_limit.x,zoom_limit.x)
	if event.is_action_pressed("zoom_out"):
		if zoom.x == zoom_limit.x:
			zoom = Vector2(1,1)
		elif zoom.x == 1:
			zoom = Vector2(zoom_limit.y,zoom_limit.y)


func _process(delta):
	var ratio = get_viewport().size.x / get_viewport().size.y
	
	limit_top = -margin
	limit_bottom = margin
	limit_left = -margin
	limit_right = margin
	
	if is_panning: translate(relative_position * zoom.x)
	relative_position = Vector2(0,0)
	
	if ratio >= 1:
		limit_left = -margin - (margin * (ratio-1) * (zoom.x-zoom_limit[0]) * 0.6)
		limit_right = margin + (margin * (ratio-1) * (zoom.x-zoom_limit[0]) * 0.6)
	else:
		limit_top = -margin - (margin * ((1/ratio)-1) * (zoom.x-zoom_limit[0]) * 0.6)
		limit_bottom = margin + (margin * ((1/ratio)-1) * (zoom.x-zoom_limit[0]) * 0.6)
	


