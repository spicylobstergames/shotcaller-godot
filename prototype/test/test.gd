extends Node
var game:Node

# self = game.test

var unit = 0
var stress = 0


func _ready():
	game = get_tree().get_current_scene()
	

func spawn_unit():
	var s = game.maps.spawn
	if unit:
		if stress: spawn_random_units()
		else:
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
			Behavior.spawn.lumberjack_hire(game.map.get_node("buildings/blue/blacksmith"), game.player_team)



func spawn_random_units():
	game.rng.randomize()
	var n = 100-26
	var s = game.maps.spawn
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
	var test_leaders = 0; # must build inventory and orders 
	var t1 = game.player_team
	var s = game.maps.spawn
	if test_leaders:
		game.maps.create(s.arthur, "mid", t1, "Vector2", Vector2(900,550))
		game.maps.create(s.bokuden, "mid", t1, "Vector2", Vector2(900,600))
		game.maps.create(s.hongi, "mid", t1, "Vector2", Vector2(900,650))
		game.maps.create(s.lorne, "mid", t1, "Vector2", Vector2(900,700))
		game.maps.create(s.raja, "mid", t1, "Vector2", Vector2(900,750))
		game.maps.create(s.robin, "mid", t1, "Vector2", Vector2(900,800))
		game.maps.create(s.rollo, "mid", t1, "Vector2", Vector2(900,850))
		game.maps.create(s.sida, "mid", t1, "Vector2", Vector2(900,900))
		game.maps.create(s.takoda, "mid", t1, "Vector2", Vector2(900,950))
		game.maps.create(s.tomyris, "mid", t1, "Vector2", Vector2(900,1000))

