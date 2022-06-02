extends Node2D

# self = game

var paused = true
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
var neutral_buildings:Array = []
var all_buildings:Array = []

var selected_unit:Node2D
var selected_leader:Node2D

var player_team:String = "blue"
var enemy_team:String = "red"
var teams = ["blue", "red"]

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


func _process(delta: float) -> void:
	if started: camera.process()
	ui.process()
	# build called after ui.minimap get_texture



func build():
	if not built:
		built = true
		
		if test.unit: # debug units
			ui.main_menu.get_node("container/play_button").play_down()
			start()
		else: 
			get_tree().paused = true
			ui.main_menu.visible = true


func start():
	if not started:
		started = true
		paused = false
		
		Engine.time_scale = 3
		
		rng.randomize()
		map.setup_lanes()
		ui.orders.build()
		unit.follow.setup_pathfind()
		unit.spawn.choose_leaders()
		
		if test.fog: map.fog.cover_map()
		
		if test.unit:
			test.spawn_unit()
		elif test.stress:
			test.spawn_random_units()
		else: 
			unit.spawn.start()
			yield(get_tree().create_timer(4), "timeout")
			unit.spawn.leaders()
			map.setup_leaders()


func _physics_process(delta):
	if started: collision.process(delta)


func can_control(unit):
	return (unit and not unit.dead) # and unit.team == game.player_team 
