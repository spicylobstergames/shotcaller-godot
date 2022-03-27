extends Camera2D

var is_panning:bool = false
var pan_position:Vector2 = Vector2.ZERO
var zoom_default = Vector2(0.66,0.66)
var zoom_limit:Vector2 = Vector2(0.32,3.34)
var margin:int = limit_right;
var position_limit:int = 720
var arrow_keys_speed:int = 4
var arrow_keys_move:Vector2 = Vector2.ZERO

var game:Node
var ui:Node
func _ready():
	game = get_tree().get_current_scene()
	ui = game.get_node("ui")
	zoom = zoom_default


func _unhandled_input(event):
	# KEYBOARD
	if event is InputEventKey:
		# move test
		if game.selected_unit and event.scancode == KEY_SPACE:
			game.selected_unit.move(get_global_mouse_position())
		
		# ARROW KEYS
		match event.scancode:
			KEY_LEFT:  arrow_keys_move.x = -arrow_keys_speed if event.is_pressed() else 0
			KEY_RIGHT: arrow_keys_move.x =  arrow_keys_speed if event.is_pressed() else 0
			KEY_UP:    arrow_keys_move.y = -arrow_keys_speed if event.is_pressed() else 0
			KEY_DOWN:  arrow_keys_move.y =  arrow_keys_speed if event.is_pressed() else 0
		
		# NUMBER KEYPAD
		if not event.is_pressed():
			var cam_move = null;
			match event.scancode:
				KEY_KP_1: cam_move = [-position_limit, position_limit]
				KEY_KP_2: cam_move = [0, position_limit]
				KEY_KP_3: cam_move = [position_limit, position_limit]
				KEY_KP_4: cam_move = [-position_limit, 0]
				KEY_KP_5: cam_move = [0, 0]
				KEY_KP_6: cam_move = [position_limit, 0]
				KEY_KP_7: cam_move = [-position_limit, -position_limit]
				KEY_KP_8: cam_move = [0, -position_limit]
				KEY_KP_9: cam_move = [position_limit, -position_limit]
			
			if cam_move: 
				zoom_reset()
				global_position = Vector2(cam_move[0], cam_move[1])

	# MOUSE PAN
	if event.is_action("pan"):
		is_panning = event.is_action_pressed("pan")
	elif event is InputEventMouseMotion:
		if is_panning: pan_position = Vector2(-1 * event.relative)
	
	# CLICK SELECTION
	if event is InputEventMouseButton and not event.pressed: 
		if event.button_index == BUTTON_RIGHT: ui.unselect(null)
		elif event.button_index == BUTTON_LEFT: ui.select(get_global_mouse_position())
	
	# TOUCH SELECTION
	if event is InputEventScreenTouch and event.pressed: ui.select(get_global_mouse_position())
		
	# TOUCH PAN
	if event is InputEventScreenTouch:
		is_panning = event.is_pressed()
	elif event is InputEventScreenDrag:
		if is_panning: pan_position = Vector2(-1 * event.relative)
	
	# ZOOM
	if event.is_action_pressed("zoom_in"):
		if zoom.x == zoom_limit.y: zoom_reset()
		elif zoom == zoom_default: zoom_in()
	if event.is_action_pressed("zoom_out"):
		if zoom.x == zoom_limit.x: zoom_reset()
		elif zoom == zoom_default: zoom_out()

func zoom_reset(): 
	zoom = zoom_default
	ui.minimap_default()
	ui.hide_hpbar()
	
func zoom_in(): 
	zoom = Vector2(zoom_limit.x,zoom_limit.x)
	ui.minimap_default()
	ui.show_hpbar()
	
func zoom_out(): 
	zoom = Vector2(zoom_limit.y, zoom_limit.y)
	ui.minimap_cover()


func _process(delta):
	var ratio = get_viewport().size.x / get_viewport().size.y
	
	# APPLY MOUSE PAN
	if is_panning: translate(pan_position * zoom.x)
	# APPLY KEYBOARD PAN
	else: translate(arrow_keys_move)
	
	pan_position = Vector2.ZERO
	
	# KEEP CAMERA PAN LIMITS
	if global_position.x > margin: global_position.x = margin
	if global_position.x < -margin: global_position.x = -margin
	if global_position.y > margin: global_position.y = margin
	if global_position.y < -margin: global_position.y = -margin
	
	# ADJUST CAMERA PAN LIMITS TO SCREEN RATIO
	limit_top = -margin
	limit_bottom = margin
	limit_left = -margin
	limit_right = margin
	
	if ratio >= 1 and zoom.x > 1:
		limit_left = -margin - (margin * (ratio-1) * (zoom.x-zoom_limit.x) * 0.65)
		limit_right = margin + (margin * (ratio-1) * (zoom.x-zoom_limit.x) * 0.65)

	if ratio <= 1 and zoom.x > 1:
		limit_top = -margin - (margin * ((1/ratio)-1) * (zoom.x-zoom_limit.x) * 0.65)
		limit_bottom = margin + (margin * ((1/ratio)-1) * (zoom.x-zoom_limit.x)* 0.65)




