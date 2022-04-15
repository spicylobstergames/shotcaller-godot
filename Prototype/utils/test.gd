extends Node
var game:Node


var infantry:PackedScene = load("res://pawns/infantry.tscn")
var archer:PackedScene = load("res://pawns/archer.tscn")


var stress = 0


func _ready():
	game = get_tree().get_current_scene()

func spawn_units():
	game.rng.randomize()
	var n = 80
	for x in range(1, n+1):
		yield(get_tree().create_timer(x/n), "timeout")
		var t = game.player_team if randf() > 0.5 else game.enemy_team
		game.map.create(infantry, "top", t, "random_map", Vector2.ZERO)
		game.map.create(infantry, "mid", t, "random_map", Vector2.ZERO)
		game.map.create(archer, "bot", t, "random_map", Vector2.ZERO)


func unit_wait_end(unit):
	if stress:
		var o = 2000
		var d = Vector2(randf()*o,randf()*o)
		if game.unit.moves: game.unit.advance.start(unit, d)


func respawn(unit):
	if stress and unit.type != "building":
		yield(get_tree().create_timer(1), "timeout")
		game.unit.spawn.spawn_unit(unit, unit.lane, unit.team, "random_map", Vector2.ZERO)


func spawn_leaders():
	var test_leaders = 0; # must build inventory and orders 
	var test_pawns = 0;
	var t1 = game.player_team
	var t2 = game.enemy_team
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
	if test_pawns:
		game.map.create(s.archer, "mid", t1, "Vector2", Vector2(900,1000))
		game.map.create(s.infantry, "mid", t1, "Vector2", Vector2(900,1050))
		game.map.create(s.archer, "mid", t2, "Vector2", Vector2(1000,1000))
		game.map.create(s.infantry, "mid", t2, "Vector2", Vector2(1000,1050))

