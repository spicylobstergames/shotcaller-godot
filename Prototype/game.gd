extends Node2D

var selected_unit:Node2D
var selected_leader:Node2D
var selectable_units:Array = []
var all_units:Array = []
var player_team:String = "blue"
var quad:Dictionary


var size := 2000
var unit_template:PackedScene = load("res://units/creeps/melee.tscn")

var two := 0

func _ready():
	var map = get_node("map")
	var bound = Rect2(Vector2.ZERO, Vector2(size,size))
	quad = {
		"top": map.create_quadtree(bound, 16, 8),
		"mid": map.create_quadtree(bound, 16, 8),
		"bot": map.create_quadtree(bound, 16, 8)
	}
	if two:
		spawn("top", "blue", Vector2(100,100))
		spawn("mid", "red", Vector2(1100,1000))
		#spawn("mid", "blue", Vector2(1000, 980))
		spawn("mid", "blue", Vector2(1000,1000))
	else:
		for x in range(1, 101):
			spawn("top", "blue", Vector2(randf()*size,randf()*size*0.2))
			spawn("mid", "blue", Vector2((size*0.3)+randf()*size*0.4,(size*0.3)+randf()*size*0.4))
			spawn("bot", "blue", Vector2(randf()*size,(size*0.8)+randf()*size*0.2))



func _process(delta: float) -> void:
	get_node("ui/top_left/fps").set_text((str(Engine.get_frames_per_second())))
	var symbols = get_node("ui/bot_left/minimap/symbols").get_children()
	for i in range(symbols.size()):
		var symbol = symbols[i]
		symbol.position = Vector2(0,-175) + all_units[i].global_position/11.4



var rng = RandomNumberGenerator.new()
func _physics_process(delta):
	rng.randomize()
	
	for lane in quad: quad[lane].clear()
	
	for unit in all_units:
		if unit.collide: quad[unit.lane].add_body(unit)
		if unit.moves and unit.state == "move":
			if circle_point_collision(unit.global_position, unit.current_destiny, unit.collision_rad):
				unit.action = "stop"
	
	for unit in all_units:
		if unit.collide and unit.moves and unit.action != "stop" and unit.state == "move":
			unit.action = "step"
			var neighbors = quad[unit.lane].get_bodies_in_radius(unit.global_position, unit.collision_rad+unit.speed)
			for unit2 in neighbors:
				if unit2.collide and unit != unit2 and unit.lane == unit2.lane:
					var next_position = unit.global_position + unit.current_speed
					if circle_collision(next_position, unit.collision_rad, unit2.global_position, unit2.collision_rad):
						unit.action = "wait"
						break
		
		match unit.action:
			"stop": unit.stop()
			"step": unit.step()
			"wait": unit.wait()



func spawn(lane, team, point):
	var unit = unit_template.instance()
	unit.lane = lane
	unit.team = team
	unit.global_position = point
	if unit.selectable: selectable_units.append(unit)
	all_units.append(unit)
	unit.get_node("animations").current_animation = "idle"
	var symbol = unit.get_node("symbol").duplicate()
	symbol.visible = true
	symbol.scale *= 0.25
	get_node("ui/bot_left/minimap/symbols").add_child(symbol)
	get_node("map").add_child(unit)
	return unit

func circle_point_collision(u1, u2, r):
	return Vector2(u1 - u2).length_squared() < r
	
func circle_collision(u1, r1, u2, r2):
	return Vector2(u1 - u2).length_squared() < (r1 + r2)




func select(point):
	var unit = get_selected_unit(Vector2(point))
	if unit:
		unselect()
		selected_unit = unit
		if unit.team == player_team and unit.type == "unit":
			selected_leader = unit
		unit.get_node("hud/state").visible = true
		unit.get_node("hud/selection").visible = true
		unit.get_node("hud/hpbar").visible = true
		get_node("ui").update_stats()


func unselect():
	if selected_unit:
		selected_unit.get_node("hud/state").visible = false
		selected_unit.get_node("hud/selection").visible = false
		selected_unit.get_node("hud/hpbar").visible = false
	selected_unit = null
	selected_leader = null
	get_node("ui").update_stats()



func get_selected_unit(point):
	for unit in selectable_units:
		if circle_point_collision(point, unit.global_position,  unit.selection_rad):
			return unit
