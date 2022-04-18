extends Camera2D
var game:Node

var is_panning:bool = false
var pan_position:Vector2 = Vector2.ZERO
var zoom_default = Vector2.ONE
var zoom_limit:Vector2 = Vector2(0.5,3.52)
var margin:int = limit_right;
var position_limit:int = 756
var arrow_keys_speed:int = 4
var arrow_keys_move:Vector2 = Vector2.ZERO


func _ready():
	game = get_tree().get_current_scene()
	zoom = zoom_default
	yield(get_tree(), "idle_frame")
	zoom_limit.y = game.map_camera.zoom.y


func _unhandled_input(event):
	# KEYBOARD
	if event is InputEventKey:
		
		# ARROW KEYS
		match event.scancode:
			
			KEY_Q: game.camera.zoom_out()
			KEY_W: game.camera.zoom_reset()
			KEY_E: game.camera.zoom_in()
			
			
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
	
	if game:
		var over_minimap = game.ui.minimap.over_minimap(event)
		# MOUSE PAN
		if event.is_action("pan") and not over_minimap:
			is_panning = event.is_action_pressed("pan")
		elif event is InputEventMouseMotion:
			if is_panning: pan_position = Vector2(-1 * event.relative)
		
		
		# TOUCH PAN
		if event is InputEventScreenTouch and not over_minimap:
			is_panning = event.is_pressed()
		elif event is InputEventScreenDrag:
			if is_panning: pan_position = Vector2(-1 * event.relative)
		
	
	# ZOOM
	if event.is_action_pressed("zoom_in"):
		var point = game.camera.get_global_mouse_position()
		var h = game.map.size / 2
		game.camera.global_position = point - Vector2(h,h)
		if zoom.x == zoom_limit.y: zoom_reset()
		elif zoom == zoom_default: zoom_in()
	if event.is_action_pressed("zoom_out"):
		if zoom.x == zoom_limit.x: zoom_reset()
		elif zoom == zoom_default: zoom_out()


func zoom_reset(): 
	zoom = zoom_default
	game.ui.show_all()
	game.ui.minimap.corner_view()
	game.unit.hud.hide_hpbars()
	
	
func zoom_in(): 
	zoom = Vector2(zoom_limit.x,zoom_limit.x)
	game.ui.hide_all_keep_stats()
	game.unit.hud.show_hpbars()
	
	
func zoom_out(): 
	zoom = Vector2(zoom_limit.y, zoom_limit.y)
	game.ui.hide_all()
	game.ui.minimap.hide_view()
	game.ui.get_node("top_mid").show()


func process():
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
	
	var s = 0.65
	if ratio >= 1 and zoom.x > 1:
		limit_left = -margin - (margin * (ratio-1) * (zoom.x-zoom_limit.x) * s)
		limit_right = margin + (margin * (ratio-1) * (zoom.x-zoom_limit.x) * s)

	if ratio < 1 and zoom.x > 1:
		limit_top = -margin - (margin * ((1/ratio)-1) * (zoom.x-zoom_limit.x) * s)
		limit_bottom = margin + (margin * ((1/ratio)-1) * (zoom.x-zoom_limit.x)* s)



