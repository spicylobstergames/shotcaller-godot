extends Node
var game:Node


var top
var mid
var bot

func _ready():
	game = get_tree().get_current_scene()


func start():

	var top_line = game.map.get_node("lanes/top")
	var mid_line = game.map.get_node("lanes/mid")
	var bot_line = game.map.get_node("lanes/bot")
	
	top = line_to_array(top_line)
	mid = line_to_array(mid_line)
	bot = line_to_array(bot_line)
	
	for team in ["red", "blue"]:
		for lane in ["top", "mid", "bot"]:
			for n in 3:
				send_pawn(lane, team)


func send_pawn(lane, team):
	var path = self[lane].duplicate()
	if team == "red": path.invert()
	var start = path.pop_front()
	var pawn = game.map.create(lane, team, "point_random_no_coll", start)
	game.unit.path.follow(pawn, path, "advance")


func line_to_array(line):
	var array = []
	for point in line.points:
		array.append(point)
	return array
