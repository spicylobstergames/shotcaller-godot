extends Node
var game:Node

# self = game.unit.spawn
var timer:Timer
var order_time = 8

var arthur:PackedScene = load("res://leaders/arthur.tscn")
var bokuden:PackedScene = load("res://leaders/bokuden.tscn")
var hongi:PackedScene = load("res://leaders/hongi.tscn")
var lorne:PackedScene = load("res://leaders/lorne.tscn")
var raja:PackedScene = load("res://leaders/raja.tscn")
var robin:PackedScene = load("res://leaders/robin.tscn")
var rollo:PackedScene = load("res://leaders/rollo.tscn")
var sida:PackedScene = load("res://leaders/sida.tscn")
var takoda:PackedScene = load("res://leaders/takoda.tscn")
var tomyris:PackedScene = load("res://leaders/tomyris.tscn")


var infantry:PackedScene = load("res://pawns/infantry.tscn")
var archer:PackedScene = load("res://pawns/archer.tscn")
var mounted:PackedScene = load("res://pawns/mounted.tscn")



var cemitery = {
	"player_infantry": [],
	"enemy_infantry": [],
	"player_archer": [],
	"enemy_archer": [],
	"player_mounted": [],
	"enemy_mounted": [],
	"player_leaders": [],
	"enemy_leaders": []
}

const leader_list = ["arthur","bokuden","hongi","lorne","raja","robin","rollo","sida","takoda","tomyris"]

var team_random_list = {"red": [], "blue": []}

func _ready():
	game = get_tree().get_current_scene()
	yield(get_tree(), "idle_frame")
	
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = order_time
	game.unit.add_child(timer)


func choose_leaders():
	
	team_random_list.blue = leader_list.duplicate()
	team_random_list.red = leader_list.duplicate()
	
	game.player_choose_leaders = []
	game.enemy_choose_leaders = []
	
	for n in 5:
		#game.player_choose_leaders.append("arthur")
		#game.enemy_choose_leaders.append("arthur")
		game.player_choose_leaders.append(random_leader(game.player_team))
		game.enemy_choose_leaders.append(random_leader(game.enemy_team))


func random_leader(team):
	var team_list = team_random_list[team]
	var index = floor(randf() * team_list.size())
	var leader = team_list[index]
	team_list.remove(index)
	return leader


func leaders():
	for team  in ["blue", "red"]:
		var counter = 0
		var leaders = game.player_choose_leaders
		if team != game.player_team: leaders = game.enemy_choose_leaders
		for leader in leaders:
			var lane = "top"
			if counter == 2: lane = "mid"
			if counter > 2: lane = "bot"
			var path = game.map.new_path(lane, team)
			var leader_node = game.map.create(self[leader], lane, team, "point_random", path.start)
			leader_node.origin = path.start
			send_leader(leader_node, path.follow)
			counter += 1


func send_leader(leader, path):
	yield(get_tree(), "idle_frame")
	game.unit.follow.start(leader, path, "advance")


func start():
	spawn_group_cycle()


func spawn_group_cycle():
	game.unit.orders.lanes_cycle()
	game.unit.orders.leaders_cycle()
	
	for team in ["red", "blue"]:
		for lane in ["top", "mid", "bot"]:
			send_pawn("archer", lane, team)
			for n in 3:
				send_pawn("infantry", lane, team)
	
	
	timer.start()
	yield(timer, "timeout")
	game.unit.orders.leaders_cycle()
	
	timer.start()
	yield(timer, "timeout")
	spawn_group_cycle()


func recycle(template, lane, team, point):
	var side = "player_"
	if team != game.player_team: side = "enemy_"
	var index = side+template
	if cemitery[index].size():
		var unit = cemitery[index].pop_back()
		unit = spawn_unit(unit, lane, team, "point_random", point)
		unit.reset_unit()
		return unit


func send_pawn(template, lane, team):
	var path = game.map.new_path(lane, team)
	var pawn = recycle(template, lane, team, path.start)
	if not pawn:
		var unit_template = infantry
		if template == "archer": unit_template = archer
		pawn = game.map.create(unit_template, lane, team, "point_random", path.start)
	game.unit.orders.set_pawn(pawn)
	game.unit.follow.start(pawn, path.follow, "advance")



func spawn_unit(unit, l, t, mode, point):
	unit.lane = l
	unit.team = t
	unit.dead = false
	unit.visible = true
	if mode == "point_random":
		point = game.utils.offset_point_random(unit, point, 25)
	if mode == "random_map":
		point = game.utils.random_point()
	unit.global_position = point
	unit.set_state("idle")
	unit.set_behavior("stop")
	return unit


func cemitery_add_pawn(unit):
	var side = "player_"
	if unit.team != game.player_team: side = "enemy_"
	var index = side+unit.display_name
	cemitery[index].append(unit)


func cemitery_add_leader(leader):
	match leader.team:
		game.player_team:
			game.unit.spawn.cemitery.player_leaders.append(leader)
		game.enemy_team:
			game.unit.spawn.cemitery.enemy_leaders.append(leader)
	
	var respawn_time = order_time * leader.respawn
	yield(get_tree().create_timer(respawn_time), "timeout")
	
	# respawn leader
	var team = leader.team
	var lane = leader.lane
	var path = game.map[leader.lane].duplicate()
	if leader.team == "red": path.invert()
	var start = path.pop_front()
	leader = spawn_unit(leader, lane, team, "point_random", start)
	leader.reset_unit()
	game.unit.follow.start(leader, path, "advance")
