extends Node
var game:Node


var unit_template:PackedScene = load("res://pawns/infantry.tscn")


var stress = 0


func _ready():
	game = get_tree().get_current_scene()

func spawn_units():
	game.rng.randomize()
	var n = 20
	for x in range(1, n+1):
		yield(get_tree().create_timer(x/n), "timeout")
		var t = game.player_team if randf() > 0.5 else game.enemy_team
		game.map.create(unit_template, "top", t, "random_no_coll", Vector2.ZERO)
		game.map.create(unit_template, "mid", t, "random_no_coll", Vector2.ZERO)
		game.map.create(unit_template, "bot", t, "random_no_coll", Vector2.ZERO)


func unit_wait_end(unit):
	if stress:
		var o = 2000
		var d = Vector2(randf()*o,randf()*o)
		if game.unit.moves: game.unit.advance.start(unit, d)


func respawn(unit):
	if stress and unit.type != "building":
		yield(get_tree().create_timer(1), "timeout")
		game.map.spawn(unit, unit.lane, unit.team, "random_no_coll", Vector2.ZERO)
