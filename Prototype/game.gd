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
	
	map.blocks.setup_quadtree()
	map.setup_buildings()
	unit.path.setup_pathfind()


func start():
	rng.randomize()
	#map.fog.cover_map()
	
	if not test.stress:
		unit.spawn.test()
		yield(get_tree().create_timer(2.0), "timeout")
		unit.spawn.start()
		
	else: test.spawn_units()


func _process(delta: float) -> void:
	ui.process()
	camera.process()


func _physics_process(delta):
	
	#map.fog.skip_start()
	#if test.stress: unit.path.find_path(utils.random_point(), utils.random_point())

	map.blocks.quad.clear()
	
	# loop 1: adds units to quad and check for arrival
	for unit1 in all_units:
		if unit1.collide: map.blocks.quad.add_body(unit1)

		#if unit1.team == player_team: map.fog.clear_sigh_skip(unit1)
		
		# arrival
		unit1.next_event  = ""
		if unit1.moves and unit1.state == "move":
			var unit1_pos = unit1.global_position + unit1.collision_position
			if utils.circle_point_collision(unit1_pos, unit1.current_destiny, unit1.collision_radius):
				unit1.next_event = "arrive"
	
	# loop 2: checks for collision
	for unit1 in all_units:
		# COLLISION
		
		# projectile
		if unit1.state == "attack" and unit1.projectile and unit1.projectile.visible and unit1.target:
			var projectile_pos = unit1.projectile.global_position
			var target = unit1.target
			var target_pos = target.global_position + target.collision_position
			if utils.circle_point_collision(target_pos, projectile_pos, target.collision_radius):
				unit.attack.take_hit(unit1, target)
		
		# units
		if unit1.collide and unit1.moves and unit1.next_event != "arrive" and unit1.state == "move":
			unit1.next_event = "move"
			var unit1_pos = unit1.global_position + unit1.collision_position + unit1.current_step
			var unit1_rad = unit1.collision_radius
			var neighbors = map.blocks.get_units_in_radius(unit1_pos, unit1_rad)
			for unit2 in neighbors:
				if unit2.collide and unit1 != unit2:
					var unit2_pos = unit2.global_position + unit2.collision_position + unit2.current_step
					var unit2_rad = unit2.collision_radius
					if utils.circle_collision(unit1_pos, unit1_rad, unit2_pos, unit2_rad):
						unit1.next_event = "collision"
						unit1.collide_target = unit2
						break
		
		# move or collide or stop
		match unit1.next_event:
			"move": unit1.on_move()
			"collision": unit1.on_collision()
			"arrive": unit1.on_arrive()
		
		# save last positions
		unit1.last_position2 = unit1.last_position
		unit1.last_position = unit1.global_position

