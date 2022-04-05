extends Node2D

var selected_unit:Node2D
var selected_leader:Node2D
var selectable_units:Array = []
var all_units:Array = []
var player_team:String = "blue"
var enemy_team:String = "red"

var size:int = 2112

var rng = RandomNumberGenerator.new()

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
	rng.randomize()
	map.setup_buildings()
	#yield(get_tree(), "idle_frame")
	#yield(get_tree().create_timer(2.0), "timeout")
	spawn()


var stress_test = 1

func spawn():
	if not stress_test:
		#map.spawn("top", "blue", Vector2(0,0))
		map.create("mid", player_team, Vector2(1000, 980))
		map.create("mid", enemy_team, Vector2(1100,1030))
		map.create("mid", enemy_team, Vector2(1100,1000))
		map.create("mid", enemy_team, Vector2(1100,970))
		#map.spawn("mid", "blue", Vector2(size,size))
	else:
		rng.randomize()
		var n = 100
		for x in range(1, n+1):
			yield(get_tree().create_timer(x/n), "timeout")
			var t = player_team if randf() > 0.5 else enemy_team
			map.create("top", t, random_no_coll())
			map.create("mid", t, random_no_coll())
			map.create("bot", t, random_no_coll())



func _process(delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	var n = game.all_units.size()
	ui.fps.set_text('fps: '+str(fps)+' u:'+str(n))

	if minimap:
		if minimap.update_map_texture: minimap.get_map_texture()
		minimap.move_symbols()



func _physics_process(delta):
	
	map.quad.clear()
	
#	if game.stress_test:
#		game.map.find_path(random_point(), random_point())
	
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
			var unit1_pos = unit1.global_position + unit1.collision_position + unit1.current_step
			var unit1_rad = unit1.collision_radius
			var neighbors = map.quad.get_units_in_radius(unit1_pos, unit1_rad)
			for unit2 in neighbors:
				if unit2.collide and unit1 != unit2:
					var unit2_pos = unit2.global_position + unit2.collision_position + unit2.current_step
					var unit2_rad = unit2.collision_radius
					if circle_collision(unit1_pos, unit1_rad, unit2_pos, unit2_rad):
						unit1.next_event = "collision"
						unit1.collide_target = unit2
						break
		
		match unit1.next_event:
			"arrive": unit1.on_arrive()
			"move": unit1.on_move()
			"collision": unit1.on_collision()
		
		unit1.last_position2 = unit1.last_position
		unit1.last_position = unit1.global_position

# UTILS


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

func limit_angle(a):
	if (a > PI): a -= PI*2
	if (a < -PI): a += PI*2
	return a

func random_point():
	var o = 50
	return Vector2(o+randf()*(game.size-o*2), o+randf()*(game.size-o*2))

func point_collides(p):
	for unit1 in all_units:
		if unit1.collide:
			var c = unit1.global_position + unit1.collision_position
			var r = unit1.collision_radius
			if circle_point_collision(p, c, r):
				return true
	return false

func random_no_coll():
	var p = random_point()
	while point_collides(p):
		p = random_point()
	return p
