extends Node
var game:Node

# self = game.test

var debug = 1

var unit = 0
var stress = 0
var leaders = 0

var s

func _ready():
	game = get_tree().get_current_scene()
	yield(get_tree(), "idle_frame")
	s = game.maps.spawn


func start():
	if debug:
		game.maps.current_map = "three_lane_map"
		game.player_choose_leaders = []
		game.enemy_choose_leaders = []
		game.mode = "match"
		game.maps.load_map(game.maps.current_map)
		game.transitions.on_transition_end()
		
		game.ui.minimap.get_map_texture()

func spawn_unit():
	if stress: spawn_random_units()
	elif leaders: spawn_leaders()
	elif unit:
		# TEST LEADER
		var leader = game.maps.create(s.arthur, "mid", "blue", "Vector2", Vector2(400,400))
		#leader.attacks = false
		Behavior.path.setup_unit_path(leader, [])
		game.player_choose_leaders=[leader.name]
		game.player_leaders=[leader]
		game.maps.setup_leaders([leader], [])
		
		# TEST LANE PAWN
#			var path = game.maps.new_path("mid", "blue")
#			var start = path.pop_front()
		var pawn = game.maps.create(s.infantry, "mid", "blue", "Vector2",  Vector2(200,600))
#			Behavior.path.setup_unit_path(pawn, path)
#			Behavior.path.start(pawn, path)
#			pawn.hp = 10000
#			pawn.current_hp = 10000
#		pawn.moves = false
		
		# TEST LUMBERJACK
		game.maps.spawn.lumberjack_hire(game.map.get_node("buildings/blue/blacksmith"), game.player_team)



func spawn_random_units():
	game.rng.randomize()
	var n = 100-26
	for x in range(1, n+1):
		yield(get_tree().create_timer(x/n), "timeout")
		var t = game.player_team if randf() > 0.5 else game.enemy_team
		game.maps.create(s.infantry, "top", t, "random_map", Vector2.ZERO)


func unit_wait_end(unit1):
	if stress:
		var o = game.map.size
		var d = Vector2(randf()*o.x,randf()*o.y)
		if unit1.agent.has_action_function("point"): unit1.agent.get_current_action().point(unit1, d)


func respawn(unit1):
	if stress and unit1.type != "building":
		yield(get_tree().create_timer(1), "timeout")
		unit1.reset_unit()
		game.maps.spawn.spawn_unit(unit1, "mid", unit1.team, "random_map", Vector2.ZERO)


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
	var y = 100
	for leader in all_leaders:
		game.maps.create(s[leader], "mid", "blue", "Vector2", Vector2(400,y))
		game.maps.create(s[leader], "mid", "red", "Vector2", Vector2(630,y))
		y += 60
