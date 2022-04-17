extends Node
var game:Node


func _ready():
	game = get_tree().get_current_scene()


func _unhandled_input(event):
	var point = game.camera.get_global_mouse_position()
	
	# KEYBOARD
	if event is InputEventKey:
		if not event.is_pressed():
			if game.selected_unit and game.selected_unit.type == "leader":
				
				if event.scancode == KEY_SPACE: 
					game.unit.move.smart_move(game.selected_unit, point)
				
				if event.scancode == KEY_A:
					game.unit.advance.start(game.selected_unit, point)
				
				if event.scancode == KEY_T:
					game.unit.path.teleport(game.selected_unit, point)
					
				if event.scancode == KEY_L:
					game.unit.path.change_lane(game.selected_unit, point)
				
				#if event.scancode == KEY_Z: attack test
				#	game.unit.attack.start(game.selected_unit, point)
				
				#if event.scancode == KEY_S: stop test
					#game.unit.move.stand(game.selected_unit)
				

	# CLICK SELECTION
	if event is InputEventMouseButton and not event.pressed: 
		if game.camera.zoom.x <= 1:
			match event.button_index:
				
				BUTTON_RIGHT: unselect()
				
				BUTTON_LEFT: 
					match game.control_state:
						"selection":
							select(point)
						
						"teleport":
							game.unit.path.teleport(game.selected_unit, point)
						
						"advance":
							game.unit.advance.start(game.selected_unit, point)
						
						"move":
							game.unit.move.smart_move(game.selected_unit, point)
						
						"lane":
							game.unit.path.change_lane(game.selected_unit, point)
		
		
		# MAP CLICK ZOOM IN
		else: 
			match event.button_index:
				BUTTON_LEFT: 
					game.camera.zoom_reset()
					var h = game.map.size / 2
					game.camera.global_position = point - Vector2(h,h)
	
	
	# TOUCH SELECTION
	if event is InputEventScreenTouch and event.pressed: 
		if game.camera.zoom.x <= 1:
			select(event.position)
		
		# MAP TOUCH ZOOM IN
		else: 
			game.camera.zoom_reset()
			var h = game.map.size / 2
			game.camera.global_position = point - Vector2(h,h)


func setup_selection(unit):
	if unit.selectable: game.selectable_units.append(unit)



func select(point):
	var unit_at_point = get_sel_unit_at_point(Vector2(point))
	if unit_at_point:
		select_unit(unit_at_point)


func select_unit(unit):
	unselect()
	game.selected_unit = unit
	
	if unit.team == game.player_team and unit.type == "leader":
		game.selected_leader = unit
		game.ui.shop.update_buttons()
		game.ui.inventories.update_buttons()
		game.ui.controls_button.disabled = false
	else:
		game.selected_leader = null
		game.ui.shop.disable_all()
		
	game.unit.hud.show_selected(unit)
	game.ui.show_select()


func unselect():
	game.control_state = "selection"
	
	if game.selected_unit:
		var unit = game.selected_unit
		game.unit.hud.hide_unselect(unit)
		
	game.selected_unit = null
	game.selected_leader = null
	game.ui.hide_unselect()
	


func get_sel_unit_at_point(point):
	for unit in game.selectable_units:
		var select_rad =  unit.selection_radius
		var select_pos = unit.global_position + unit.selection_position
		if game.utils.circle_point_collision(point, select_pos, select_rad):
			return unit

