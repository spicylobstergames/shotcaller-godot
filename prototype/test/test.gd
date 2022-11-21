extends Node
var game:Node

# self = game.test

var unit = 0
var stress = 0


func _ready():
	game = get_tree().get_current_scene()
	EventMachine.register_listener(Events.CHEAT_CODE, self, "apply_cheat_code")


func spawn_unit():
	var s = Behavior.spawn
	if unit: 
		
#		var dummy = game.maps.create(s.arthur, "mid", "red", "Vector2", Vector2(930,900))

#
#		var inf = game.maps.create(s.arthur, "mid", "red", "Vector2",  Vector2(900,900))
#		inf.set_behavior("stand")
#		inf.hp = 100
#		inf.current_hp = 100
#
		var leader = game.maps.create(s.nagato, "mid", "blue", "Vector2", Vector2(940,900))
		#game.maps.create(s.archer, "mid", "blue", "Vector2",  Vector2(800,650))
		var dummy = game.maps.create(s.infantry, "mid", "red", "Vector2",  Vector2(1020,650))
		dummy.set_behavior("stand")
		dummy.hp = 10000
		dummy.current_hp = 10000
		#game.maps.create(s.takoda, "mid", "red", "Vector2",  Vector2(1000,900))
#		leader.hp = 100
#		leader.current_hp = 100
		
		game.player_choose_leaders=[leader.name]
		game.player_leaders=[leader]
		game.maps.setup_leaders()
	
	if stress: spawn_random_units()


func spawn_random_units():
	game.rng.randomize()
	var n = 18
	var s = Behavior.spawn
	for x in range(1, n+1):
		yield(get_tree().create_timer(x/n), "timeout")
		var t = game.player_team if randf() > 0.5 else game.enemy_team
		game.maps.create(s.infantry, "top", t, "random_map", Vector2.ZERO)
		game.maps.create(s.infantry, "mid", t, "random_map", Vector2.ZERO)
		game.maps.create(s.archer, "bot", t, "random_map", Vector2.ZERO)


func unit_wait_end(unit1):
	if stress:
		var o = game.map.size
		var d = Vector2(randf()*o,randf()*o)
		if unit1.moves: Behavior.advance.point(unit1, d)


func respawn(unit1):
	if stress and unit1.type != "building":
		yield(get_tree().create_timer(1), "timeout")
		unit1.reset_unit()
		Behavior.spawn.spawn_unit(unit1, unit1.lane, unit1.team, "random_map", Vector2.ZERO)


func spawn_leaders():
	var test_leaders = 0; # must build inventory and orders 
	var t1 = game.player_team
	var s = Behavior.spawn
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


func apply_cheat_code(code):
	match code:
		"SHADOW":
			for unit1 in game.all_units:
				if unit1.has_node("light"): unit1.get_node("light").shadow_enabled = false
		"WIN":
			EventMachine.register_event(Events.GAME_END, ["PLAYER"])
		"LOSE":
			EventMachine.register_event(Events.GAME_END, ["ENEMY"])
