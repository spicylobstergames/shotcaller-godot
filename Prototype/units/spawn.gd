extends Node
var game:Node

var spawn_time = 16

var arthur:PackedScene = load("res://leaders/arthur.tscn")
var bokuden:PackedScene = load("res://leaders/bokuden.tscn")
var hongi:PackedScene = load("res://leaders/hongi.tscn")
var lorne:PackedScene = load("res://leaders/lorne.tscn")
var raja:PackedScene = load("res://leaders/raja.tscn")
var robin:PackedScene = load("res://leaders/robin.tscn")
var rollo:PackedScene = load("res://leaders/rollo.tscn")
var sami:PackedScene = load("res://leaders/sami.tscn")
var takoda:PackedScene = load("res://leaders/takoda.tscn")
var tomyris:PackedScene = load("res://leaders/tomyris.tscn")


var infantry:PackedScene = load("res://pawns/infantry.tscn")
var archer:PackedScene = load("res://pawns/archer.tscn")


var top:Array
var mid:Array
var bot:Array


var cemitery = {
	"infantry": [],
	"archer": [],
	"player_leaders": [],
	"enemy_leaders": []
}


func _ready():
	game = get_tree().get_current_scene()


func test():
	var test_heores = 0;
	var test_pawns = 0;
	var t1 = game.player_team
	var t2 = game.enemy_team
	
	game.map.create(arthur, "mid", t1, "Vector2", Vector2(1000,1100))
	game.map.create(arthur, "mid", t2, "Vector2", Vector2(1150,1000))
	
	if test_heores:
		game.map.create(arthur, "mid", t1, "Vector2", Vector2(80,550))
		game.map.create(bokuden, "mid", t1, "Vector2", Vector2(900,600))
		game.map.create(hongi, "mid", t1, "Vector2", Vector2(900,650))
		game.map.create(lorne, "mid", t1, "Vector2", Vector2(900,700))
		game.map.create(raja, "mid", t1, "Vector2", Vector2(900,750))
		game.map.create(robin, "mid", t1, "Vector2", Vector2(900,800))
		game.map.create(rollo, "mid", t1, "Vector2", Vector2(900,850))
		game.map.create(sami, "mid", t1, "Vector2", Vector2(900,900))
		game.map.create(takoda, "mid", t1, "Vector2", Vector2(900,950))
		game.map.create(tomyris, "mid", t1, "Vector2", Vector2(900,1000))
	if test_pawns:
		game.map.create(archer, "mid", t1, "Vector2", Vector2(1000,1000))
		game.map.create(infantry, "mid", t2, "Vector2", Vector2(1100,750))
	



func start():

	var top_line = game.map.get_node("lanes/top")
	var mid_line = game.map.get_node("lanes/mid")
	var bot_line = game.map.get_node("lanes/bot")
	
	top = line_to_array(top_line)
	mid = line_to_array(mid_line)
	bot = line_to_array(bot_line)
	
	spawn_group()


func spawn_group():
	game.unit.orders.setup_lanes_priority()
	game.unit.orders.setup_leaders()
	
	for team in ["red", "blue"]:
		for lane in ["top", "mid", "bot"]:
			send_pawn("archer", lane, team)
			for n in 3:
				send_pawn("infantry", lane, team)
				
	yield(get_tree().create_timer(spawn_time/2), "timeout")
	game.unit.orders.setup_leaders()
	
	yield(get_tree().create_timer(spawn_time/2), "timeout")
	spawn_group()


func recycle(template, lane, team, point):
	if cemitery[template].size():
		var unit = cemitery[template].pop_back()
		unit = spawn_unit(unit, lane, team, "point_random_no_coll", point)
		unit.reset_unit()
		return unit


func send_pawn(template, lane, team):
	var path = self[lane].duplicate()
	if team == "red": path.invert()
	var start = path.pop_front()
	var pawn = recycle(template, lane, team, start)
	if not pawn:
		var unit_template = infantry
		if template == "archer": unit_template = archer
		pawn = game.map.create(unit_template, lane, team, "point_random_no_coll", start)
	game.unit.orders.setup_pawn(pawn, lane)
	game.unit.path.follow(pawn, path, "advance")


func line_to_array(line):
	var array = []
	for point in line.points:
		array.append(point)
	return array



func spawn_unit(unit, l, t, mode, point):
	unit.lane = l
	unit.team = t
	unit.dead = false
	unit.visible = true
	if mode == "point_random_no_coll":
		point = game.utils.point_random_no_coll(unit, point, 25)
	if mode == "random_no_coll":
		point = game.utils.random_no_coll(unit)
	unit.global_position = point
	unit.set_state("idle")
	unit.set_behavior("stop")
	return unit
