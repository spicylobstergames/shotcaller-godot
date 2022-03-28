extends Node2D

var selected_unit:Node2D
var selected_leader:Node2D
var selectable_units:Array = []
var all_units:Array = []
var player_team:String = "blue"

var unit_template:PackedScene = load("res://units/unit.tscn")

var quad
var two = 0

func _ready():
	var map = get_node("map")
	quad = map.create_quadtree(Rect2(Vector2.ZERO, Vector2(2000,2000)), 16, 8)
	if two:
		#spawn(Vector2(1000,1020))
		spawn(Vector2(1000,1000))
		#spawn(Vector2(1000, 980))
		spawn(Vector2(950,1000))
	else:
		for x in range(16):
			for y in range(16):
				spawn(Vector2(100+x*90,100+y*90))

func _process(delta: float) -> void:
	get_node("ui/top_left/fps").set_text((str(Engine.get_frames_per_second())))
	var symbols = get_node("ui/bot_left/minimap/symbols").get_children()
	for i in range(symbols.size()):
		var symbol = symbols[i]
		symbol.position = Vector2(0,-175) + all_units[i].global_position/11.4
	
var even = 0
#var steps = 8
var rng = RandomNumberGenerator.new()
func _physics_process(delta):
	rng.randomize()
	quad.clear();
	
	for unit in all_units:
		if unit.collide: 
			quad.add_body(unit)
		if unit.moves and unit.state == "move":
			if circle_point_collision(unit.global_position, unit.current_destiny, unit.collision_rad_sq):
				unit.stop()
	
	for i in range(all_units.size()):
		var action = "move"
		var unit = all_units[i]
		#if i%steps == even:
		if unit.collide and unit.moves and unit.state == "move":
			var neighbors = quad.get_bodies_in_radius(unit.global_position, unit.collision_rad_sq)
			for unit2 in neighbors:
				if unit2.collide and unit != unit2:
					var next_position = unit.global_position + unit.current_speed
					if circle_collision(next_position, unit.collision_rad_sq, unit2.global_position, unit2.collision_rad_sq):
						action = "wait"
						break
		
		if action == "wait": unit.wait()
		elif unit.state == "move": unit.step()
		
		#even = (even+1)%steps


func spawn(point):
	var unit = unit_template.instance()
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


