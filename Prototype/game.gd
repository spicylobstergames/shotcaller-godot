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
	#yield(get_tree(), "idle_frame")
	#yield(get_tree().create_timer(2.0), "timeout")
	spawn()


var stress_test = 0

func spawn():
	if not stress_test:
		#map.spawn("top", "blue", Vector2(0,0))
		map.spawn("mid", "red", Vector2(1100,1000))
		map.spawn("mid", "blue", Vector2(1000, 980))
		#map.spawn("mid", "blue", Vector2(size,size))
	else:
		for x in range(1, 151):
			yield(get_tree().create_timer(x/150), "timeout")
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
			var unit1_pos = unit1.global_position + unit1.collision_position
			if circle_point_collision(unit1_pos, unit1.current_destiny, unit1.collision_radius):
				unit1.next_event = "arrive"
	
	for unit1 in all_units:
		# COLLISION
		if unit1.collide and unit1.moves and unit1.next_event != "arrive" and unit1.state == "move":
			unit1.next_event = "move"
			var unit1_pos = unit1.global_position + unit1.collision_position
			var neighbors = map.quad.get_units_in_radius(unit1_pos, unit1.collision_radius+unit1.speed)
			for unit2 in neighbors:
				if unit2.collide and unit1 != unit2:
					var next_position = unit1_pos + unit1.current_step
					var unit1_rad = unit1.collision_radius
					var unit2_pos = unit2.global_position + unit2.collision_position
					var unit2_rad = unit2.collision_radius
					if circle_collision(next_position, unit1_rad, unit2_pos, unit2_rad):
						unit1.next_event = "collision"
						break
		
		match unit1.next_event:
			"arrive": unit1.on_arrive()
			"move": unit1.on_move()
			"collision": unit1.on_collision()



func circle_point_collision(p, c, r):
	return Vector2(p - c).length() < r
	
	
func circle_collision(c1, r1, c2, r2):
	return Vector2(c1 - c2).length() < (r1 + r2)
	
	
	
func sort_by_hp(array):
	var sorted = []
	for neighbor in array:
		sorted.append({
			"unit": neighbor,
			"hp": neighbor.current_hp
		})
	sorted.sort_custom(self, "compare_hp")
	return sorted


func compare_hp(a: Dictionary, b: Dictionary) -> bool:
	return a.hp < b.hp


func sort_by_distance(unit1, array):
	var sorted = []
	for unit2 in array:
		sorted.append({
			"unit": unit2,
			"distance": unit1.global_position.distance_to(unit2.global_position)
		})
	sorted.sort_custom(self, "compare_distance")
	return sorted
	

func compare_distance(a: Dictionary, b: Dictionary) -> bool:
	return a.distance < b.distance
