extends Node
var game:Node

# self = game.test

var debug = 0

var unit = 0
var stress = 0
var leaders = 0

var s

func _ready():
	game = get_tree().get_current_scene()
	await get_tree().process_frame # wait for idle frame
	s = game.spawn


func start():
	if debug:
		game.maps.current_map = "three_lane_map"
		WorldState.set_state("game_mode", "campaign")
		game.maps.load_map(game.maps.current_map)
		game.transitions.on_transition_end()
		game.ui.minimap.get_map_texture()

func spawn_unit():
	if stress: spawn_random_units()
	elif leaders: spawn_leaders()
	elif unit:
		# TEST LEADER
		var leader = game.spawn.create(s.arthur, "mid", "blue", "Vector2", Vector2(400,400))
		#leader.attacks = false
		Behavior.path.setup_unit_path(leader, [])
		WorldState.set_state("player_leaders_names", [leader.name])
		WorldState.set_state("player_leaders", [leader]);
		game.maps.setup_leaders([leader], [])
		
		# TEST LANE PAWN
#		var path = Behavior.path.new_lane_path("mid", "blue")
#		var start = path.pop_front()
		var pawn = game.spawn.create(s.infantry, "mid", "blue", "Vector2",  Vector2(200,600))
#		Behavior.path.setup_unit_path(pawn, path)
#		Behavior.path.start(pawn,path)
		pawn.hp = 10000
		pawn.current_hp = 10000
#		pawn.moves = false
		
		# TEST LUMBERJACK
		game.spawn.lumberjack_hire(WorldState.get_state("map").get_node("buildings/blue/blacksmith"), WorldState.get_state("player_team"))



func spawn_random_units():
	game.rng.randomize()
	var n = 100-26
	for x in range(1, n+1):
		await get_tree().create_timer(x/n).timeout
		var t = WorldState.get_state("player_team") if randf() > 0.5 else WorldState.get_state("enemy_team")
		game.spawn.create(s.infantry, "top", t, "random_map", Vector2.ZERO)


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
	var y = 100
	for leader in all_leaders:
		game.spawn.create(s[leader], "mid", "blue", "Vector2", Vector2(400,y))
		game.spawn.create(s[leader], "mid", "red", "Vector2", Vector2(630,y))
		y += 60
