extends Node2D

var selected_unit:Node2D
var selected_leader:Node2D
var selectable_units:Array = []
var all_units:Array = []
var player_team:String = "blue"
var enemy_team:String = "red"

var size:int = 2112

var rng = RandomNumberGenerator.new()

var map:Node
var unit:Node
var camera:Node
var ui:Node
var minimap:Node
var utils:Node
var test:Node

func _ready():
	map = get_node("map")
	unit = get_node("map/unit")
	camera = get_node("camera")
	ui = get_node("ui")
	minimap = get_node("map_camera")
	utils = get_node("utils")
	test = get_node("test")
	
	unit.path.setup_quadtree()
	unit.path.setup_pathfind()


func start():
	rng.randomize()
	map.setup_buildings()
	
	#yield(get_tree(), "idle_frame")
	
	
	#map.spawn("top", "blue", Vector2(0,0))
	map.create("mid", player_team, "Vector2", Vector2(1000, 980))
	map.create("mid", enemy_team, "Vector2", Vector2(1100,1030))
	map.create("mid", enemy_team, "Vector2", Vector2(1100,1000))
	map.create("mid", enemy_team, "Vector2", Vector2(1100,970))
	#map.spawn("mid", "blue", Vector2(size,size))	
	
	spawn_start()


func spawn_start():
	if not test.stress:
		yield(get_tree().create_timer(2.0), "timeout")
		unit.spawn.start()
	else: test.spawn_units()



func _process(delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	var n = all_units.size()
	ui.fps.set_text('fps: '+str(fps)+' u:'+str(n))

	if minimap:
		if minimap.update_map_texture: minimap.get_map_texture()
		minimap.move_symbols()



func _physics_process(delta):
	#if test.stress: unit.path.find_path(utils.random_point(), utils.random_point())

	unit.path.quad.clear()
	
	for unit1 in all_units:
		if unit1.collide: unit.path.quad.add_body(unit1)
		unit1.next_event  = ""
		if unit1.moves and unit1.state == "move":
			var unit1_pos = unit1.global_position + unit1.collision_position
			if utils.circle_point_collision(unit1_pos, unit1.current_destiny, unit1.collision_radius):
				unit1.next_event = "arrive"
	
	for unit1 in all_units:
		# COLLISION
		if unit1.collide and unit1.moves and unit1.next_event != "arrive" and unit1.state == "move":
			unit1.next_event = "move"
			var unit1_pos = unit1.global_position + unit1.collision_position + unit1.current_step
			var unit1_rad = unit1.collision_radius
			var neighbors = unit.path.quad.get_units_in_radius(unit1_pos, unit1_rad)
			for unit2 in neighbors:
				if unit2.collide and unit1 != unit2:
					var unit2_pos = unit2.global_position + unit2.collision_position + unit2.current_step
					var unit2_rad = unit2.collision_radius
					if utils.circle_collision(unit1_pos, unit1_rad, unit2_pos, unit2_rad):
						unit1.next_event = "collision"
						unit1.collide_target = unit2
						break
		
		match unit1.next_event:
			"arrive": unit1.on_arrive()
			"move": unit1.on_move()
			"collision": unit1.on_collision()
		
		unit1.last_position2 = unit1.last_position
		unit1.last_position = unit1.global_position

