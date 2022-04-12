extends Node
var game:Node


var arthur:PackedScene = load("res://leaders/arthur.tscn")
var bokuden:PackedScene = load("res://leaders/bokuden.tscn")
var hongi:PackedScene = load("res://leaders/hongi.tscn")
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

func _ready():
	game = get_tree().get_current_scene()


func test():
	
	yield(get_tree(), "idle_frame")
	game.map.create(arthur, "mid", game.player_team, "Vector2", Vector2(900,600))
	game.map.create(bokuden, "mid", game.player_team, "Vector2", Vector2(900,650))
	game.map.create(hongi, "mid", game.player_team, "Vector2", Vector2(900,700))
	game.map.create(raja, "mid", game.player_team, "Vector2", Vector2(900,750))
	game.map.create(robin, "mid", game.player_team, "Vector2", Vector2(900,800))
	game.map.create(rollo, "mid", game.player_team, "Vector2", Vector2(900,850))
	game.map.create(sami, "mid", game.player_team, "Vector2", Vector2(900,900))
	game.map.create(takoda, "mid", game.player_team, "Vector2", Vector2(900,950))
	game.map.create(tomyris, "mid", game.player_team, "Vector2", Vector2(900,1000))
	#game.map.create(rollo, "mid", game.enemy_team, "Vector2", Vector2(900,1000))
	game.map.create(archer, "mid", game.player_team, "Vector2", Vector2(1000,1000))
	#game.map.create(infantry, "mid", game.player_team, "Vector2", Vector2(1000,1030))
	#game.map.create(archer, "mid", game.enemy_team, "Vector2", Vector2(1100,1000))
	game.map.create(infantry, "mid", game.enemy_team, "Vector2", Vector2(1100,750))
	
	game.map.setup_leaders()


func start():

	var top_line = game.map.get_node("lanes/top")
	var mid_line = game.map.get_node("lanes/mid")
	var bot_line = game.map.get_node("lanes/bot")
	
	top = line_to_array(top_line)
	mid = line_to_array(mid_line)
	bot = line_to_array(bot_line)
	
	for team in ["red", "blue"]:
		for lane in ["top", "mid", "bot"]:
			send_pawn("archer", lane, team)
			for n in 3:
				send_pawn("infantry", lane, team)


func send_pawn(template, lane, team):
	var path = self[lane].duplicate()
	if team == "red": path.invert()
	var start = path.pop_front()
	var unit_template = infantry
	if template == "archer": unit_template = archer
	var pawn = game.map.create(unit_template, lane, team, "point_random_no_coll", start)
	game.unit.path.follow(pawn, path, "advance")


func line_to_array(line):
	var array = []
	for point in line.points:
		array.append(point)
	return array
