extends Node2D

var dragging: bool = false
var select_rect: RectangleShape2D = RectangleShape2D.new()

func _ready() -> void:
# warning-ignore:return_value_discarded
	Player.connect("switch_team", self, "_on_Player_switch_team")


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT:
		if Units.selected_units.size() != 0:
			_unselect()
			
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			update()
			# We only want to start a drag if there's no selection.
			#if Units.selected_units.size() == 0:
			#	dragging = true
			#	drag_start = get_global_mouse_position()
			# If there is a selection, give it the target.
			#else:
			#	Units.move(Units.selected_units, get_global_mouse_position())

		# Button released while dragging.
		#elif dragging:
		else:
			#dragging = false
			update()
			var drag_start = get_global_mouse_position()
			var drag_end = Vector2(drag_start.x+1, drag_start.y+1)
			drag_start.x -= 1
			drag_start.y -= 1
			#var drag_end = get_global_mouse_position()
			# Extents are measured from center.
			select_rect.extents = (drag_end - drag_start) / 2
			var space = get_world_2d().direct_space_state
			var query = Physics2DShapeQueryParameters.new()
			query.collide_with_bodies = false
			query.collide_with_areas = true
			query.collision_layer = 256
			query.set_shape(select_rect)
			query.transform = Transform2D(0, (drag_end + drag_start) / 2)
			# Result is an array of dictionaries. Each has a "collider" key.
			
			#for q in space.intersect_shape(query):
			#	var u = q.collider.owner
			if space.intersect_shape(query) and space.intersect_shape(query)[0] and space.intersect_shape(query)[0].collider.owner:
				var u = space.intersect_shape(query)[0].collider.owner
				_select(u)

	if event is InputEventMouseMotion and dragging:
		# Draw the box while dragging.
		update()

# selection drag rectangle
#func _draw():
	#if dragging:
	#	draw_rect(Rect2(drag_start, get_global_mouse_position() - drag_start), Color.white, false, 2.0)
	#	draw_circle(get_global_mouse_position(), 2, Color.green)


func _select(u):
	_unselect()
	u.get_node("HUD/Selection").visible = true
	get_tree().get_current_scene().get_node("GUI/BotLeftContainer/StatsWindow").update_window(u)
	Units.selected_units.append(u)
	var in_leaders = u.get_node("Attributes").primary.unit_type in [Units.TypeID.Leader]
	if u.team == Player.selected_team and in_leaders:
		Leaders.selected_leader = u

func _unselect():
	for u in Units.selected_units:
		if is_instance_valid(u): u.get_node("HUD/Selection").visible = false
		
	get_tree().get_current_scene().get_node("GUI/BotLeftContainer/StatsWindow").update_window(false)
	Units.selected_units = []
	Leaders.selected_leader = null

func _on_Player_switch_team() -> void:
	if Units.selected_units.size() != 0:
		#for u in Units.selected_units:
		_unselect()
		
