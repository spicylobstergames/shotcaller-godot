extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func _unhandled_input(event):
	var point = game.camera.get_global_mouse_position()
	
	# KEYBOARD
	if event is InputEventKey:
		if game.selected_unit and not event.is_pressed():
			if event.scancode == KEY_SPACE: 
				game.unit.move.start(game.selected_unit, point)
			if event.scancode == KEY_A:
				game.unit.attack.start(game.selected_unit, point)
			if event.scancode == KEY_Z:
				game.unit.advance.start(game.selected_unit, point)
			if event.scancode == KEY_X:
				game.unit.path.follow(game.selected_unit, [point], "move")
			if event.scancode == KEY_C:
				game.selected_unit.current_path.append(point)

	# CLICK SELECTION
	if event is InputEventMouseButton and not event.pressed: 
		match event.button_index:
			BUTTON_LEFT: select(point)
			BUTTON_RIGHT: unselect()
	
	
	# TOUCH SELECTION
	if event is InputEventScreenTouch and event.pressed: 
		select(event.position)



func select(point):
	var unit_at_point = get_sel_unit_at_point(Vector2(point))
	if unit_at_point:
		unselect()
		var unit = unit_at_point
		game.selected_unit = unit
		if unit.team == game.player_team and unit.type == "leader":
			game.selected_leader = unit
		unit.get_node("hud/state").visible = true
		unit.get_node("hud/selection").visible = true
		unit.get_node("hud/hpbar").visible = true
		game.ui.update_stats()
	

func unselect():
	if game.selected_unit:
		var unit = game.selected_unit
		unit.get_node("hud/state").visible = false
		unit.get_node("hud/selection").visible = false
		unit.get_node("hud/hpbar").visible = false
	game.selected_unit = null
	game.selected_leader = null
	game.ui.update_stats()


func get_sel_unit_at_point(point):
	for unit in game.selectable_units:
		var select_rad =  unit.selection_radius
		var select_pos = unit.global_position + unit.selection_position
		if game.utils.circle_point_collision(point, select_pos, select_rad):
			return unit
