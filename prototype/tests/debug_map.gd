extends Node


var game:Node

# self = game.test

@export var debug = 1


@export var unit = 0
@export var stress = 0
@export var leaders = 0


@onready var walls = get_node("tiles/walls/Walls")
@onready var trees = get_node("tiles/trees/Trees")
@onready var fog = get_node("fog")

@export var size := Vector2(512, 512)
var mid := Vector2(size.x/2, size.y/2)

@export var tile_size = 64
var half_tile_size = tile_size / 2

@export var neutrals = []

@export var fog_of_war:bool = true

@export var camera_limit = Vector2(225,225)
@export var zoom_limit:Vector2 = Vector2(0.5,2)

var unit_container:Node2D
var block_container:Node2D
var projectile_container:Node2D


func _ready():
	game = get_tree().get_current_scene()
	await get_tree().process_frame # wait for idle frame


func start():
	if debug:
		WorldState.set_state("game_mode", "match")
		WorldState.set_state("player_team", "blue")
		game.map_manager.current_map = "debug_map"
		game.start()

func spawn_unit():
	if stress: spawn_random_units()
	elif leaders: spawn_leaders()
	elif unit:
		# TEST LEADER
		var leader = game.spawn.create(game.spawn.leader_scene("arthur"), "mid", "blue", "Vector2", mid)
		#leader.attacks = false
		leader.current_path = []
		WorldState.set_state("player_leaders_names", [leader.name])
		WorldState.set_state("player_leaders", [leader]);
		WorldState.set_state("player_team", "blue")
		WorldState.set_state("enemy_leaders_names", [])
		WorldState.set_state("enemy_leaders", []);
		WorldState.set_state("enemy_team", "red")
		game.map_manager.setup_leaders([leader], [])
		
		# TEST LANE PAWN
#		var path = Goap.get_goal("WalkLane").get_lane_path("mid", "blue")
#		var start = path.pop_front()
		var pawn = game.spawn.create(game.spawn.pawn_scene("infantry"), "mid", "red", "Vector2",  Vector2(mid.x+50,mid.y))
#		pawn.current_path = path
#		Navigation.start(pawn,path)
		pawn.hp = 10000
		pawn.current_hp = 10000
#		pawn.moves = false
		
		# TEST LUMBERJACK
		var map = WorldState.get_state("map")
		var blacksmith = map.get_node_or_null("buildings/blue/blacksmith")
		if blacksmith:
			game.spawn.lumberjack_hire(blacksmith, WorldState.get_state("player_team"))



func spawn_random_units():
	game.rng.randomize()
	var n = 100-26
	for x in range(1, n+1):
		await get_tree().create_timer(x/n).timeout
		var t = "blue" if randf() > 0.5 else "red"
		game.spawn.create(game.spawn.pawn_scene("infantry"), "top", t, "random_map", Vector2.ZERO)


func unit_wait_end(unit1):
	if stress:
		var o = WorldState.get_state("map").size
		var d = Vector2(randf()*o.x,randf()*o.y)
		if unit1.agent.has_action_function("point"): unit1.agent.get_current_action().point(unit1, d)


func respawn(unit1):
	if stress and unit1.type != "building":
		await get_tree().create_timer(1).timeout
		unit1.reset_unit()
		game.spawn.spawn_unit(unit1, "mid", unit1.team, "random_map", Vector2.ZERO)


func spawn_leaders():
	var all_leaders = [
		"arthur", 
		"bokuden", 
		"hongi", 
		"joan", 
		"lorne", 
		"nagato", 
		"osman", 
		"raja", 
		"robin", 
		"rollo", 
		"sida", 
		"takoda", 
		"tomyris" 
	]
	var y = 10
	for leader in all_leaders:
		game.spawn.create(game.spawn.leader_scene(leader), "mid", "blue", "Vector2", Vector2(100,y))
		game.spawn.create(game.spawn.leader_scene(leader), "mid", "red", "Vector2", Vector2(330,y))
		y += 60
