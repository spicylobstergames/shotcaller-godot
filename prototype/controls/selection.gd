extends Node
var game:Node

# self = game.election

func _ready():
	game = get_tree().get_current_scene()


func input(event):
	var point = CraftyCamera.get_global_mouse_position()
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
				control_state_order(point)
	
	# TOUCH SELECTION
	if event is InputEventScreenTouch and not event.is_pressed(): 
		if selected_unit:
			control_state_order(event.position)
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
	
	if unit.is_controllable() and unit.type == "leader":
		WorldState.set_state("selected_leader", unit)
		game.ui.shop.update_buttons()
		game.ui.inventories.update_buttons()
		game.ui.unit_control_button.disabled = false
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


func control_state_order(point):
	var selected_unit = WorldState.get_state("selected_unit")
	if selected_unit:
		if selected_unit.is_controllable():
			if selected_unit.moves: 
				game.control_state = "move"
			elif selected_unit.attacks: # controllable towers and buildings
				game.control_state = "attack"
		
		if selected_unit.attacks:
			var target_unit = get_sel_unit_at_point(Vector2(point))
			if (target_unit and target_unit.team != selected_unit.team): 
				game.control_state = "attack"
		
		match game.control_state:
			"selection": deselect()
			"teleport": teleport(selected_unit, point)
			"advance": advance(selected_unit, point)
			"move": move(selected_unit, point)
			"lane": change_lane(selected_unit, point)
			"attack": attack(selected_unit, point)


func advance(unit, point):
	if unit and unit.attacks and unit.moves and unit.is_controllable() and no_delay(unit):
		Goap.get_action("Order").issue_player_order(unit, "advance", point)


func attack(unit, point):
	if unit.attacks and unit.is_controllable() and no_delay(unit):
		Goap.get_action("Order").issue_player_order(unit, "attack", point)


func teleport(unit, point):
	if unit.moves and unit.is_controllable() and no_delay(unit):
		Goap.get_action("Order").issue_player_order(unit, "teleport", point)


func change_lane(unit, point):
	if unit.moves and unit.is_controllable() and no_delay(unit):
		Goap.get_action("Order").issue_player_order(unit, "lane", point)


func move(unit, point):
	if unit.moves and unit.is_controllable() and no_delay(unit):
		Goap.get_action("Order").issue_player_order(unit, "move", point)


func stand(unit):
	if unit.is_controllable() and no_delay(unit):
		Goap.get_action("Order").issue_player_order(unit, "stand")
