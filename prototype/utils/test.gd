extends Node
var game:Node

# self = game.test

var unit = 0
var fog = 0
var stress = 0


func _ready():
	game = get_tree().get_current_scene()


func spawn_unit():
	var s = game.unit.spawn
	if unit: 
		
#		var dummy = game.map.create(s.arthur, "mid", "red", "Vector2", Vector2(930,900))
#		dummy.set_behavior("stand")
#		dummy.hp = 100
#		dummy.current_hp = 100
#
#		var inf = game.map.create(s.arthur, "mid", "red", "Vector2",  Vector2(900,900))
#		inf.set_behavior("stand")
#		inf.hp = 100
#		inf.current_hp = 100
#
		var leader = game.map.create(s.sida, "mid", "blue", "Vector2", Vector2(850,1400))
		game.map.create(s.archer, "mid", "blue", "Vector2",  Vector2(820,800))
		game.map.create(s.mounted, "mid", "red", "Vector2",  Vector2(1000,800))
		#game.map.create(s.infantry, "mid", "red", "Vector2",  Vector2(1000,800))
#		leader.hp = 100
#		leader.current_hp = 100
		
		game.player_choose_leaders=[leader.name]
		game.player_leaders=[leader]
		game.map.setup_leaders()
	
	if stress: spawn_random_units()


func spawn_random_units():
	game.rng.randomize()
	var n = 80
	var s = game.unit.spawn
	for x in range(1, n+1):
		yield(get_tree().create_timer(x/n), "timeout")
		var t = game.player_team if randf() > 0.5 else game.enemy_team
		game.map.create(s.infantry, "top", t, "random_map", Vector2.ZERO)
		game.map.create(s.infantry, "mid", t, "random_map", Vector2.ZERO)
		game.map.create(s.archer, "bot", t, "random_map", Vector2.ZERO)


func unit_wait_end(unit1):
	if stress:
		var o = 2000
		var d = Vector2(randf()*o,randf()*o)
		if game.unit.moves: game.unit.advance.start(unit1, d)


func respawn(unit1):
	if stress and unit1.type != "building":
		yield(get_tree().create_timer(1), "timeout")
		game.unit.spawn.spawn_unit(unit1, unit1.lane, unit1.team, "random_map", Vector2.ZERO)


func spawn_leaders():
	var test_leaders = 0; # must build inventory and orders 
	var t1 = game.player_team
	var s = game.unit.spawn
	if test_leaders:
		game.map.create(s.arthur, "mid", t1, "Vector2", Vector2(900,550))
		game.map.create(s.bokuden, "mid", t1, "Vector2", Vector2(900,600))
		game.map.create(s.hongi, "mid", t1, "Vector2", Vector2(900,650))
		game.map.create(s.lorne, "mid", t1, "Vector2", Vector2(900,700))
		game.map.create(s.raja, "mid", t1, "Vector2", Vector2(900,750))
		game.map.create(s.robin, "mid", t1, "Vector2", Vector2(900,800))
		game.map.create(s.rollo, "mid", t1, "Vector2", Vector2(900,850))
		game.map.create(s.sida, "mid", t1, "Vector2", Vector2(900,900))
		game.map.create(s.takoda, "mid", t1, "Vector2", Vector2(900,950))
		game.map.create(s.tomyris, "mid", t1, "Vector2", Vector2(900,1000))

