extends Camera2D

var is_panning:bool = false

var relative_position:Vector2 = Vector2(0.0,0.0)

var zoom_limit:Vector2 = Vector2(0.32,3.52)

var margin:int = limit_right;

var position_limit:int = 620

var arrow_speed:int = 4

var key_move:Vector2 = Vector2(0,0)

func _unhandled_input(event):
	# KEYBOARD
	if event is InputEventKey:
		# ARROW KEYS
		if event.scancode == KEY_LEFT:  key_move.x = -arrow_speed if event.is_pressed() else 0
		if event.scancode == KEY_RIGHT: key_move.x =  arrow_speed if event.is_pressed() else 0
		if event.scancode == KEY_UP:    key_move.y = -arrow_speed if event.is_pressed() else 0
		if event.scancode == KEY_DOWN:  key_move.y =  arrow_speed if event.is_pressed() else 0
		
		# NUMBER KEYPAD
		if event.is_pressed() and event.scancode == KEY_KP_1:
			global_position = Vector2(-position_limit, position_limit)
		if event.is_pressed() and event.scancode == KEY_KP_2:
			global_position = Vector2(0, position_limit)
		if event.is_pressed() and event.scancode == KEY_KP_3:
			global_position = Vector2(position_limit, position_limit)
		if event.is_pressed() and event.scancode == KEY_KP_4:
			global_position = Vector2(-position_limit, 0)
		if event.is_pressed() and event.scancode == KEY_KP_5:
			global_position = Vector2(0, 0)
		if event.is_pressed() and event.scancode == KEY_KP_6:
			global_position = Vector2(position_limit, 0)
		if event.is_pressed() and event.scancode == KEY_KP_7:
			global_position = Vector2(-position_limit, -position_limit)
		if event.is_pressed() and event.scancode == KEY_KP_8:
			global_position = Vector2(0, -position_limit)
		if event.is_pressed() and event.scancode == KEY_KP_9:
			global_position = Vector2(position_limit, -position_limit)


	# TOUCH
	if event is InputEventScreenTouch:
		is_panning = event.is_pressed()
	elif event is InputEventScreenDrag:
		if is_panning: relative_position = Vector2(-1 * event.relative)
	
	# MOUSE
	if event.is_action("pan"):
		is_panning = event.is_action_pressed("pan")
	elif event is InputEventMouseMotion:
		if is_panning: relative_position = Vector2(-1 * event.relative)
	
	# ZOOM WHEEL
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
	
	if is_panning: translate(relative_position * zoom.x)
	relative_position = Vector2(0,0)
	
	translate(key_move)
	
	if global_position.x > position_limit: global_position.x = position_limit
	if global_position.x < -position_limit: global_position.x = -position_limit
	if global_position.y > position_limit: global_position.y = position_limit
	if global_position.y < -position_limit: global_position.y = -position_limit
	
	limit_top = -margin
	limit_bottom = margin
	limit_left = -margin
	limit_right = margin
	
	if ratio >= 1 and zoom.x > 1:
		limit_left = -margin - (margin * (ratio-1) * (zoom.x-zoom_limit[0]) * 0.65)
		limit_right = margin + (margin * (ratio-1) * (zoom.x-zoom_limit[0]) * 0.65)

	if ratio <= 1 and zoom.x > 1:
		limit_top = -margin - (margin * ((1/ratio)-1) * (zoom.x-zoom_limit[0]) * 0.65)
		limit_bottom = margin + (margin * ((1/ratio)-1) * (zoom.x-zoom_limit[0]) * 0.65)


