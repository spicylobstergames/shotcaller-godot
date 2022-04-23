extends Node2D

var time = 0
var player_kills = 0
var player_deaths = 0
var player_choose_leaders:Array = []
var player_leaders:Array = []
var player_units:Array = []
var player_buildings:Array = []
var enemy_kills = 0
var enemy_deaths = 0
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

var built:bool = false
var started:bool = false


func _ready():
	unit = get_node("map/unit")
	map_camera = get_node("map_camera")
	utils = get_node("utils")
	test = get_node("test")
	
	map.setup_buildings()
	map.blocks.setup_quadtree()


func build():
	if not built:
		built = true
		
		if test.unit:
			ui.main_menu.get_node("container/play_button").play_down()
			start()
		else:
			#get_tree().paused = true
			ui.main_menu.visible = true


func start():
	if not started:
		started = true
		
		#yield(get_tree(), "idle_frame")
		rng.randomize()
		map.setup_lanes()
		unit.path.setup_pathfind()
		ui.orders.setup_lanes()
		unit.spawn.choose_leaders()
		
		
		if test.fog: map.fog.cover_map()
		
		if test.unit:
			test.spawn_unit()
			#test.spawn_leaders()
		
		else: 
			yield(get_tree().create_timer(1.0), "timeout")
			unit.spawn.start()
			yield(get_tree().create_timer(1.0), "timeout")
			unit.spawn.leaders()
			map.setup_leaders()


func _process(delta: float) -> void:
	ui.process()
	camera.process()


func _physics_process(delta):
	if started: collision.process(delta)


