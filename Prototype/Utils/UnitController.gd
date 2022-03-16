extends Node2D

var dragging: bool = false
var select_rect: RectangleShape2D = RectangleShape2D.new()

var selected_leader

func _ready() -> void:
# warning-ignore:return_value_discarded
	Player.connect("switch_team", self, "_on_Player_switch_team")


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT:
		if Units.units_selected.size() != 0:
			_unselect()
			
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			update()
			# We only want to start a drag if there's no selection.
			#if Units.units_selected.size() == 0:
			#	dragging = true
			#	drag_start = get_global_mouse_position()
			# If there is a selection, give it the target.
			#else:
			#	Units.move(Units.units_selected, get_global_mouse_position())

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
			Units.units_selected = []
			
			#for q in space.intersect_shape(query):
			#	var u = q.collider.owner
			if space.intersect_shape(query) and space.intersect_shape(query)[0] and space.intersect_shape(query)[0].collider.owner:
				var u = space.intersect_shape(query)[0].collider.owner
				var is_leader = u.get_node("Attributes").primary.unit_type in [Units.TypeID.Leader]
				if u.team == Player.selected_team and is_leader: 
			#	Units.units_selected.append(u)
		
			#for u in Units.units_selected:
					_select(u)
			else:
				_unselect()

	if event is InputEventMouseMotion and dragging:
		# Draw the box while dragging.
		update()


#func _draw():
	#if dragging:
	#	draw_rect(Rect2(drag_start, get_global_mouse_position() - drag_start), Color.white, false, 2.0)
	#	draw_circle(get_global_mouse_position(), 2, Color.green)


func _select(u):
	u.is_selected = true
	u.get_node("HUD/Selection").visible = true
	get_node("/root/TestScene/GUI/StatsWindow").update_window(u)
	Units.units_selected = [u]
	selected_leader = u

func _unselect():
	if selected_leader:
		selected_leader.is_selected = false
		selected_leader.get_node("HUD/Selection").visible = false
		get_node("/root/TestScene/GUI/StatsWindow").update_window(false)
		Units.units_selected = []
		selected_leader = false
	

func _on_Player_switch_team() -> void:
	if Units.units_selected.size() != 0:
		#for u in Units.units_selected:
		_unselect()
		
