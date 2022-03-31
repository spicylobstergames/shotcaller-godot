extends Node2D

var selected_unit:Node2D
var selected_leader:Node2D
var selectable_units:Array = []
var all_units:Array = []
var player_team:String = "blue"

var size:int = 2112

var game:Node = self
var map:Node
var unit:Node
var camera:Node
var ui:Node
var minimap:Node

func _ready():
	map = get_node("map")
	unit = get_node("map/unit")
	camera = get_node("camera")
	ui = get_node("ui")
	minimap = get_node("map_camera")


func start():
	map.setup_buildings()
	spawn()


var two = 1

func spawn():
	if two:
		#map.spawn("top", "blue", Vector2(0,0))
		map.spawn("mid", "red", Vector2(1100,1000))
		map.spawn("mid", "blue", Vector2(1000, 980))
		#map.spawn("mid", "blue", Vector2(size,size))
	else:
		for x in range(1, 101):
			map.spawn("top", "blue", Vector2(randf()*size,randf()*size*0.2))
			map.spawn("mid", "blue", Vector2((size*0.3)+randf()*size*0.4,(size*0.3)+randf()*size*0.4))
			map.spawn("bot", "blue", Vector2(randf()*size,(size*0.8)+randf()*size*0.2))



func _process(delta: float) -> void:
	ui.fps.set_text((str(Engine.get_frames_per_second())))

	if minimap:
		if minimap.update_map_texture: minimap.get_map_texture()
		minimap.move_symbols()


var rng = RandomNumberGenerator.new()
func _physics_process(delta):
	rng.randomize()
	
	map.quad.clear()
	
	for unit1 in all_units:
		if unit1.collide: map.quad.add_body(unit1)
		# BEHAVIOUR
		unit1.next_event  = ""
		if unit1.moves and unit1.state == "move":
			if circle_point_collision(unit1.global_position, unit1.current_destiny, unit1.collision_rad):
				unit1.next_event = "arrive"
	
	for unit1 in all_units:
		# COLLISION
		if unit1.collide and unit1.moves and unit1.next_event != "arrive" and unit1.state == "move":
			unit1.next_event = "move"
			var neighbors = map.quad.get_bodies_in_radius(unit1.global_position, unit1.collision_rad+unit1.speed)
			for unit2 in neighbors:
				if unit2.collide and unit1 != unit2: # and unit.lane == unit2.lane:
					var next_position = unit1.global_position + unit1.current_step
					if circle_collision(next_position, unit1.collision_rad, unit2.global_position, unit2.collision_rad):
						unit1.next_event = "collision"
						break
		
		match unit1.next_event:
			"arrive": unit1.on_arrive()
			"move": unit1.on_move()
			"collision": unit1.on_collision()



func circle_point_collision(u1, u2, r):
	return Vector2(u1 - u2).length() < r
	
	
func circle_collision(u1, r1, u2, r2):
	return Vector2(u1 - u2).length() < (r1 + r2)
