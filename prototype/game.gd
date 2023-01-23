extends Node

# self = game

var paused:bool = true
var time:int = 0
var player_kills:int = 0
var player_deaths:int = 0
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

var rng = RandomNumberGenerator.new()

onready var background = get_node("background")
onready var maps = get_node("maps")
onready var camera = get_node("camera")
onready var ui = get_node("ui")
onready var collision = get_node("collision")
onready var selection = get_node("selection")
onready var utils = get_node("utils")
onready var test = get_node("test")


var map:Node

var control_state = "selection"

var built:bool = false
var started:bool = false
var ended:bool = false

var victory:String


func _ready():
	
	#Engine.time_scale = 2
	#get_tree().paused = true
	ui.show_main_menu()
#	randomize()
	
	WorldState.set_state("is_game_active", false)
	var timer = Timer.new()
	timer.wait_time = 1
	add_child(timer)
	timer.start()
	timer.connect("timeout", self, "_one_sec")

#runs logic that is only run once per second
func _one_sec():
	EventMachine.register_event(Events.ONE_SEC, [])



func _process(delta: float) -> void:
	if started: camera.process()
	ui.process()


func build():
	if not built:
		built = true
		
		if test.unit: # debug units
			resume()


func map_loaded():
	if not started:
		started = true
		resume()
		WorldState.set_state("is_game_active", true)
		
		maps.setup_buildings()
		map.blocks.setup_quadtree()
		
		rng.randomize()
		maps.setup_lanes()
		ui.orders_menu.build()
		Behavior.follow.setup_pathfind()
		
		if test.unit:
			test.spawn_unit()
		elif test.stress:
			test.spawn_random_units()
		else: 
			Behavior.spawn.pawns()

			ui.get_node("score_board").visible = false
			yield(get_tree().create_timer(4), "timeout")
			
			Behavior.spawn.leaders()
			EventMachine.register_listener(Events.ONE_SEC, self, "units_sec_cycle")


func _physics_process(delta):
	if started:
		collision.process(delta)
		Goap.process(all_units, delta)


func can_control(unit1):
	return (unit1 and unit1.type == "leader" and unit1.team == player_team and not unit1.dead) 


func units_sec_cycle(): # called every second 
	if not paused:
		for unit1 in all_units:
			var has_regen = (unit1.regen > 0)
			var is_building = (unit1.type == "building")
			var is_neutral = (unit1.team == "neutral")
			if can_control(unit1):
				unit1.set_delay()
				ui.inventories.update_consumables(unit1)
			if ( has_regen and (!is_building or ( is_building and is_neutral )) ):
				unit1.set_regen()
				unit1.set_dot()


func resume():
	paused = false
	get_tree().paused = false
	Behavior.spawn.timer.paused = false;
	ui.show_all()
	ui.hide_menus()
	ui.minimap.visible = true
	ui.rect_layer.visible = true
	ui.scoreboard.visible = false


func pause():
	paused = true
	get_tree().paused = true
	Behavior.spawn.timer.paused = true
	ui.show_pause_menu()


func exit():
	get_tree().quit(0)


func reload():
	EventMachine.reset()
# warning-ignore:return_value_discarded
	get_tree().reload_current_scene()
	Behavior._ready()


func start(red_team_leaders, blue_team_leaders, _player_team, map_index):
	player_team = _player_team
	if player_team == "blue":
		player_choose_leaders = blue_team_leaders
		enemy_choose_leaders = red_team_leaders
	else:
		player_choose_leaders = red_team_leaders
		enemy_choose_leaders = blue_team_leaders
		
	if map_index == 1:
		maps.current_map = "one_lane_map"
	else:
		maps.current_map = "three_lane_map"
	
	maps.load_map(maps.current_map)
	background.visible = false
	ui.minimap.update_map_texture = true
	resume()
