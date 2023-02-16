extends Node

# self = game


signal game_ready
signal game_started
signal game_map_loaded
signal game_resumed
signal game_paused
signal game_ended


var built:bool = false
var started:bool = false
var ended:bool = false
var paused:bool = true
var victory:bool


var time:int = 0
var player_kills:int = 0
var player_deaths:int = 0
var enemy_kills:int = 0
var enemy_deaths:int = 0

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
var neutral_buildings:Array = []
var all_buildings:Array = []

var map:Node2D
var selected_unit:Node2D
var selected_leader:Node2D

var player_team:String = "blue"
var enemy_team:String = "red"
var control_state:String = "selection"

onready var background = get_node("background")
onready var maps = get_node("maps")
onready var camera = get_node("camera")
onready var ui = get_node("ui")
onready var collision = get_node("collision")
onready var selection = get_node("selection")
onready var utils = get_node("utils")
onready var test = get_node("test")

var rng = RandomNumberGenerator.new()


func _ready():
	
#	Engine.time_scale = 2
#	get_tree().paused = true
#	randomize()

	if test.unit or test.stress:
		ui.main_menu.quick_start()
	else:
		ui.show_main_menu()
	
	emit_signal("game_ready")


func units_sec_cycle(): # called every second 
	if not paused:
		for unit1 in all_units:
			var has_regen = (unit1.regen > 0)
			var is_building = (unit1.type == "building")
			var is_neutral = (unit1.team == "neutral")
			if unit1.type == "leader": ui.inventories.update_consumables(unit1)
			if can_control(unit1): unit1.set_delay()
			if ( has_regen and (!is_building or ( is_building and is_neutral )) ):
				unit1.set_regen()
				unit1.set_dot()


func _physics_process(delta):
	if started:
		collision.process(delta)
		Behavior.follow.draw_path(selected_unit)
		#Goap.process(all_units, delta)


func can_control(unit1):
	return (unit1 
		and unit1.team == player_team 
		and not unit1.dead
		and (test.unit or unit1.type == "leader")
	) 



func start():
	background.visible = false
	maps.load_map(maps.current_map)
	# takes map snapshop for minimap
	ui.minimap.update_map_texture = true
	
	resume()


func _process(delta: float) -> void:
	camera.process()
	ui.process()


func map_loaded():
	if not started:
		emit_signal("game_started")
		started = true
		
		resume()
		WorldState.set_state("is_game_active", true)
		WorldState.start_one_sec_timer()
		
		rng.randomize()
		WorldState.one_sec_timer.connect("timeout", self, "units_sec_cycle")
		
		if test.unit:
			test.spawn_unit()
		elif test.stress:
			test.spawn_random_units()
		else: 
			Behavior.spawn.pawns()

			yield(get_tree().create_timer(4), "timeout")
			
			Behavior.spawn.leaders()
			
	
	emit_signal("game_map_loaded")


func resume():
	paused = false
	get_tree().paused = false
	WorldState.one_sec_timer.paused = false
	Behavior.spawn.timer.paused = false
	ui.show_all()
	ui.hide_menus()
	ui.minimap.visible = true
	ui.rect_layer.visible = true
	ui.scoreboard.visible = false
	emit_signal("game_resumed")


func pause():
	paused = true
	get_tree().paused = true
	WorldState.one_sec_timer.paused = true
	Behavior.spawn.timer.paused = true
	ui.show_pause_menu()
	emit_signal("game_paused")


func end(winner: bool):
	paused = true
	get_tree().paused = true
	WorldState.one_sec_timer.paused = true
	Behavior.spawn.timer.paused = true
	ended = true
	victory = winner
	ui.scoreboard.handle_game_end(winner)
	emit_signal("game_ended")



func exit():
	get_tree().quit(0)

