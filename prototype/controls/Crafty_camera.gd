extends Camera2D

# Autoload
# self = Crafty_camera

signal camera_zoom_changed

# PAN
var is_panning:bool = false
var pan_position:Vector2 = Vector2.ZERO
# ZOOM
var is_zooming:bool = false
var zoom_default:Vector2 = Vector2.ONE
var zoom_limit:Vector2 = Vector2.ONE
var default_zoom_sensitivity := .2
# KEYBOARD
var arrow_keys_move:Vector2 = Vector2.ZERO
var arrow_keys_speed := 4
# TOUCH
var pinch_sensitivity := 3
var _touches = {}
var _touches_info = {
	"num_touch_last_frame":0, 
	"radius":0,
	"last_radius":0, 
	"total_pan":0, 
	"last_avg_pos":Vector2.ZERO, 
	"cur_avg_pos":Vector2.ZERO
}

var actions = InputMap.get_actions()


func get_action(event):
	for action in actions:
		if event.is_action_pressed(action) or event.is_action_released(action):
			return action


func input(event):
	var pressed = event.is_pressed()
	
	match get_action(event):
		"ui_left":  arrow_keys_move.x = -arrow_keys_speed if pressed else 0
		"ui_right": arrow_keys_move.x =  arrow_keys_speed if pressed else 0
		"ui_up":    arrow_keys_move.y = -arrow_keys_speed if pressed else 0
		"ui_down":  arrow_keys_move.y =  arrow_keys_speed if pressed else 0

		# KEYBOARD
	if event is InputEventKey and WorldState.get_state("game_started"):
		
		match event.keycode:
			# LEADER KEYS
			KEY_1: focus_leader(1)
			KEY_2: focus_leader(2)
			KEY_3: focus_leader(3)
			KEY_4: focus_leader(4)
			KEY_5: focus_leader(5)
		
		# NUMBER KEYPAD
		if not pressed:
			var cam_move = null;
			var x = WorldState.get_state("map_mid").x
			var y = WorldState.get_state("map_mid").y
			match event.keycode:
				# nine grid cam movement
				KEY_KP_1: cam_move = [-x, y]
				KEY_KP_2: cam_move = [0, y]
				KEY_KP_3: cam_move = [x, y]
				KEY_KP_4: cam_move = [-x, 0]
				KEY_KP_5: cam_move = [0, 0]
				KEY_KP_6: cam_move = [x, 0]
				KEY_KP_7: cam_move = [-x, -y]
				KEY_KP_8: cam_move = [0, -y]
				KEY_KP_9: cam_move = [x, -y]
				# ZOOM KEYS
				KEY_KP_SUBTRACT: full_zoom_out()
				KEY_KP_ADD: full_zoom_in()
			
			if cam_move: 
				zoom_reset()
				global_position = Vector2(cam_move[0], cam_move[1])
	
	if WorldState.get_state("game_started"):
		var over_minimap = WorldState.get_state("over_minimap")
		# MOUSE PAN
		if event.is_action("pan") and not over_minimap:
			is_panning = event.is_action_pressed("pan")
		elif event is InputEventMouseMotion:
			if is_panning: pan_position = Vector2(-1 * event.relative)
		
		
		# TOUCH PAN AND ZOOM
		if event is InputEventScreenTouch and not over_minimap:
			if not pressed:
				_touches.erase(event.index)
				if _touches.size() == 0:
					_touches_info.last_radius = 0
					_touches_info.last_avg_pos = Vector2.ZERO
					_touches_info.radius = 0
					_touches_info.cur_avg_pos = Vector2.ZERO
			else:
				is_panning = true
				if(_touches.size() == 0):
					_touches_info.last_avg_pos = event.position
					_touches_info.cur_avg_pos = event.position
				_touches[event.index] = {"start":event, "current":event}
		if event is InputEventScreenDrag:
			if not event.index in _touches:
				_touches[event.index] = {"start":event, "current":event}
				is_panning = true
			if is_panning : 
				_touches[event.index]["current"] = event
				var avg_touch = Vector2(0,0)
				for key in _touches:
					avg_touch += _touches[key]["current"].position
				avg_touch /= _touches.size()
				_touches_info.cur_avg_pos = avg_touch
				pan_position = Vector2(-1 * (_touches_info.cur_avg_pos - _touches_info.last_avg_pos))
		
		# ZOOM
		if event.is_action_pressed("zoom_in"):
			_zoom_camera(1)
		if event.is_action_pressed("zoom_out"):
			_zoom_camera(-1)


func map_loaded():
	position = Vector2.ZERO
	var mid = WorldState.get_state("map_mid")
	offset = mid
	zoom_limit = WorldState.get_state("zoom_limit")
	var zoom_out = zoom_limit.x
	zoom = Vector2(zoom_out, zoom_out)


func focus_leader(index):
	var game = get_tree().get_current_scene()
	if game.player_leaders.size() >= index:
		var leader = game.player_leaders[index-1]
		if leader:
			focus_unit(leader)
			game.selection.select_unit(leader)
			game.ui.leaders_icons.buttons_focus(leader)

func focus_unit(unit):
	var mid = WorldState.get_state("map_mid")
	global_position = unit.global_position - mid


func zoom_reset():
	zoom = zoom_default
	emit_signal("camera_zoom_changed")
	
	
func full_zoom_in():
	zoom = Vector2(zoom_limit.x,zoom_limit.x)
	emit_signal("camera_zoom_changed")
	
	
func full_zoom_out():
	zoom = Vector2(zoom_limit.y, zoom_limit.y)
	emit_signal("camera_zoom_changed")


func _zoom_camera(dir):
	var new_zoom = zoom + Vector2(default_zoom_sensitivity, default_zoom_sensitivity) * dir
	
	var zoom_in_limit = zoom_limit.x
	var zoom_out_limit = zoom_limit.y
	
	new_zoom.x = clamp(new_zoom.x, zoom_in_limit, zoom_out_limit)
	new_zoom.y = clamp(new_zoom.y, zoom_in_limit, zoom_out_limit)
	
	zoom = new_zoom
	emit_signal("camera_zoom_changed")


func process():
	if WorldState.get_state("game_started"): 
		
		# APPLY MOUSE PAN
		if is_panning: translate(pan_position / zoom.x)
		# APPLY KEYBOARD PAN
		else: translate(arrow_keys_move)
		
		if(_touches.size()>0):
			_touches_info.radius = abs(_touches.values()[0].current.position.x - _touches_info.cur_avg_pos.x) + abs(_touches.values()[0].current.position.y - _touches_info.cur_avg_pos.y)
			if(_touches_info.last_radius != 0 && _touches.size() > 1):
				_zoom_camera(pinch_sensitivity * (_touches_info["last_radius"] - _touches_info["radius"]) / _touches_info["last_radius"])
		
		# RESET VARS AND SET LAST VARS
		_touches_info.last_radius = _touches_info.radius
		_touches_info.last_avg_pos = _touches_info.cur_avg_pos
		_touches_info.num_touch_last_frame = _touches.size()
		pan_position = Vector2.ZERO
		
		# KEEP CAMERA PAN LIMITS
		var camera_limit = WorldState.get_state("map_camera_limit")
		var x = camera_limit.x
		var y = camera_limit.y
		global_position.x = clamp(global_position.x, -x, x)
		global_position.y = clamp(global_position.y, -y, y)


func reset():
	get_tree().reload_current_scene()
