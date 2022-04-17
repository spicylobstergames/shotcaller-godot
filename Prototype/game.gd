extends Node2D


var player_choose_leaders:Array = []
var player_leaders:Array = []
var player_units:Array = []
var player_buildings:Array = []
var enemy_choose_leaders:Array = []
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

onready var map = get_node("map")
onready var camera = get_node("camera")
onready var ui = get_node("ui")
onready var selection = get_node("selection")
onready var collision = get_node("collision")

var unit:Node
var utils:Node
var test:Node
var map_camera:Node

var control_state = "selection"

var started:bool = false


func _ready():
	unit = get_node("map/unit")
	map_camera = get_node("map_camera")
	utils = get_node("utils")
	test = get_node("test")
	
	map.setup_buildings()
	map.blocks.setup_quadtree()


func start():
	started = true
	
	#yield(get_tree(), "idle_frame")
	rng.randomize()
	map.setup_lanes()
	unit.path.setup_pathfind()
	unit.spawn.choose_leaders()
	ui.orders.setup_lanes()

	#map.fog.cover_map()
	
	if test.unit:
		test.spawn_unit()
		#test.spawn_leaders()

	else: 
		
		yield(get_tree().create_timer(2.0), "timeout")
		unit.spawn.start()
		yield(get_tree().create_timer(2.0), "timeout")
		unit.spawn.leaders()


func _process(delta: float) -> void:
	ui.process()
	camera.process()


func _physics_process(delta):
	if started: collision.process(delta)
	
	#if test.stress: unit.path.find_path(utils.random_point(), utils.random_point())

	#map.fog.skip_start()
		#if unit1.team == player_team: map.fog.clear_sigh_skip(unit1)
	
