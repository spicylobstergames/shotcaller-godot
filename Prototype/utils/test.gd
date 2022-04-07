extends Node
var game:Node


var infantry:PackedScene = load("res://pawns/infantry.tscn")
var archer:PackedScene = load("res://pawns/archer.tscn")


var stress = 0


func _ready():
	game = get_tree().get_current_scene()

func spawn_units():
	game.rng.randomize()
	var n = 20
	for x in range(1, n+1):
		yield(get_tree().create_timer(x/n), "timeout")
		var t = game.player_team if randf() > 0.5 else game.enemy_team
		game.map.create(infantry, "top", t, "random_no_coll", Vector2.ZERO)
		game.map.create(infantry, "mid", t, "random_no_coll", Vector2.ZERO)
		game.map.create(archer, "bot", t, "random_no_coll", Vector2.ZERO)


func unit_wait_end(unit):
	if stress:
		var o = 2000
		var d = Vector2(randf()*o,randf()*o)
		if game.unit.moves: game.unit.advance.start(unit, d)


func respawn(unit):
	if stress and unit.type != "building":
		yield(get_tree().create_timer(1), "timeout")
		game.map.spawn(unit, unit.lane, unit.team, "random_no_coll", Vector2.ZERO)
