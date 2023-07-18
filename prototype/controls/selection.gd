extends Node
var game:Node

# self = game.election

func _ready():
	game = get_tree().get_current_scene()


func input(event):
	var point = Crafty_camera.get_global_mouse_position()
	var selected_unit = WorldState.get_state("selected_unit")
	# KEYBOARD
	if event is InputEventKey:
		if not event.is_pressed():
			if selected_unit:
				match event.keycode:
					
					KEY_E: move(selected_unit, point)
					KEY_R: advance(selected_unit, point)
					KEY_Q: teleport(selected_unit, point)
					KEY_W: change_lane(selected_unit, point)
					
					KEY_A: attack(selected_unit, point) 
					KEY_S: stand(selected_unit)
	
	# CLICK SELECTION
	if event is InputEventMouseButton and not event.is_pressed(): 
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				select(point)
			MOUSE_BUTTON_RIGHT:
				control_state(point)
	
	# TOUCH SELECTION
	if event is InputEventScreenTouch and not event.is_pressed(): 
		if selected_unit:
			control_state(event.position)
		else:
			select(event.position)



func setup_selection(unit):
	if unit.selectable: WorldState.get_state("selectable_units").append(unit)


func select(point):
	var unit = get_sel_unit_at_point(Vector2(point))
	if unit:
		select_unit(unit)


func select_unit(unit):
	deselect()
	WorldState.set_state("selected_unit", unit)
	
	if unit.is_controllable():
		if unit.moves: 
			if unit.attacks: 
				game.control_state = "advance"
			else:
				game.control_state = "move"
		elif unit.attacks:
				game.control_state = "attack"
					
	if unit.is_controllable() and unit.type == "leader":
		WorldState.set_state("selected_leader", unit)
		game.ui.shop.update_buttons()
		game.ui.inventories.update_buttons()
		game.ui.unit_controls_button.disabled = false
		game.ui.active_skills.update_buttons()
		game.ui.leaders_icons.buttons_focus(unit)
	else:
		WorldState.set_state("selected_leader", null)
		game.ui.shop.disable_all()
	
	unit.hud.show_selected()
	game.ui.show_select()
	
	if unit.display_name == "blacksmith" and not game.ui.shop.visible: 
		game.ui.shop_button.button_down()


func deselect():
	game.control_state = "selection"
	var selected_unit = WorldState.get_state("selected_unit")
	if selected_unit:
		selected_unit.hud.hide_unselect()
		
		if (selected_unit.display_name == "blacksmith" 
			and game.ui.shop.visible): 
			game.ui.shop_button.button_down()
	
	game.ui.leaders_icons.buttons_unfocus()
	
	WorldState.set_state("selected_unit", null)
	WorldState.set_state("selected_leader", null)
	game.ui.hide_unselect()


func get_sel_unit_at_point(point):
	for unit in WorldState.get_state("selectable_units"):
		var select_rad = unit.selection_radius
		var select_pos = unit.global_position + unit.selection_position
		if Utils.circle_point_collision(point, select_pos, select_rad):
			return unit


func get_unit_at_point(point):
	for unit in WorldState.get_state("all_units"):
		var select_rad =  unit.selection_radius
		var select_pos = unit.global_position + unit.selection_position
		if Utils.circle_point_collision(point, select_pos, select_rad):
			return unit


func no_delay(unit):
	return unit.curr_control_delay <= 0 


func control_state(point):
	var selected_unit = WorldState.get_state("selected_unit")
	match game.control_state:
		"selection": deselect()
		"teleport": teleport(selected_unit, point)
		"advance": advance(selected_unit, point)
		"move": move(selected_unit, point)
		"lane": change_lane(selected_unit, point)
		"attack": attack(selected_unit, point)


func advance(unit, point):
	if unit and unit.attacks and unit.moves and unit.is_controllable() and no_delay(unit):
		var order_point = order(unit, point)
		Behavior.advance.smart(unit, order_point)


func attack(unit, point):
	if unit.attacks and unit.is_controllable() and no_delay(unit):
		var order_point = order(unit, point)
		Behavior.attack.point(unit, order_point)


func teleport(unit, point):
	if unit.moves and unit.is_controllable() and no_delay(unit):
		var order_point = order(unit, point)
		Behavior.move.teleport(unit, order_point)


func change_lane(unit, point):
	if unit.moves and unit.is_controllable() and no_delay(unit):
		var order_point = order(unit, point)
		Behavior.path.change_lane(unit, order_point)


func move(unit, point):
	if unit.moves and unit.is_controllable() and no_delay(unit):
		var order_point = order(unit, point)
		Behavior.move.smart(unit, order_point)


func stand(unit):
	if unit.is_controllable() and no_delay(unit):
		order(unit, null)
		Behavior.move.stand(unit)


func order(unit, point):
	unit.agent.set_state("has_player_command", true)
	Behavior.attack.set_target(unit, null)
	unit.start_control_delay()
	if point:
		var building = Utils.get_building(point)
		if building:
			var opponent = unit.opponent_team()
			match building.team:
				# attack enemy buildings
				opponent: unit.after_arive = "attack"
				# conquer neutral buildings
				"neutral":
					point = front_door_point(building)
					unit.after_arive = "conquer"
				unit.team:
					point = front_door_point(building)
					# stop next to friendly buildings
					unit.after_arive = "stop"
					# pray on friendly churches
					if building.display_name == "church":
						unit.after_arive = "pray"
		
		return point


func front_door_point(building):
	var point = building.global_position
	point.y += WorldState.get_state("map").tile_size/2
	return point
