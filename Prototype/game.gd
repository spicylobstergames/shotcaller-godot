extends Node2D

var player_leaders:Array = []
var player_units:Array = []
var player_buildings:Array = []
var enemy_leaders:Array = []
var enemy_units:Array = []
var enemy_buildings:Array = []
var all_units:Array = []
var selectable_units:Array = []

var selected_unit:Node2D
var selected_leader:Node2D

var player_team:String = "blue"
var enemy_team:String = "red"

var rng = RandomNumberGenerator.new()

var map:Node
var unit:Node
var camera:Node
var map_camera:Node
var ui:Node
var controls:Node
var collision:Node
var utils:Node
var test:Node

var started:bool = false


func _ready():
	map = get_node("map")
	unit = get_node("map/unit")
	camera = get_node("camera")
	map_camera = get_node("map_camera")
	ui = get_node("ui")
	controls = get_node("controls")
	collision = get_node("collision")
	utils = get_node("utils")
	test = get_node("test")
	
	map.setup_buildings()


func start():
	started = true
	
	rng.randomize()
	map.blocks.setup_quadtree()
	unit.path.setup_pathfind()
	#map.fog.cover_map()
	
	if test.stress:
		test.spawn_units()
	else: 
		yield(get_tree(), "idle_frame")
		unit.spawn.test()
		map.setup_leaders()
		ui.orders_container.setup()
		yield(get_tree().create_timer(5.0), "timeout")
		unit.spawn.start()
	


func _process(delta: float) -> void:
	ui.process()
	camera.process()


func _physics_process(delta):
	if started: collision.process(delta)
	
	#if test.stress: unit.path.find_path(utils.random_point(), utils.random_point())

	#map.fog.skip_start()
		#if unit1.team == player_team: map.fog.clear_sigh_skip(unit1)
	
