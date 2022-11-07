extends Node
var game:Node

# self = Behavior.spawn
var timer:Timer
var order_time = 8


var arthur:PackedScene = load("res://leaders/arthur.tscn")
var bokuden:PackedScene = load("res://leaders/bokuden.tscn")
var hongi:PackedScene = load("res://leaders/hongi.tscn")
var lorne:PackedScene = load("res://leaders/lorne.tscn")
var nagato:PackedScene = load("res://leaders/nagato.tscn")
var osman:PackedScene = load("res://leaders/osman.tscn")
var raja:PackedScene = load("res://leaders/raja.tscn")
var robin:PackedScene = load("res://leaders/robin.tscn")
var rollo:PackedScene = load("res://leaders/rollo.tscn")
var sida:PackedScene = load("res://leaders/sida.tscn")
var takoda:PackedScene = load("res://leaders/takoda.tscn")
var tomyris:PackedScene = load("res://leaders/tomyris.tscn")

var infantry:PackedScene = load("res://pawns/infantry.tscn")
var archer:PackedScene = load("res://pawns/archer.tscn")
var mounted:PackedScene = load("res://pawns/mounted.tscn")

var lumberjack:PackedScene = load("res://neutrals/lumberjack.tscn")

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

var team_random_list = {"red": [], "blue": []}

func _ready():
	game = get_tree().get_current_scene()
	yield(get_tree(), "idle_frame")
	
	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = order_time
	game.add_child(timer)

func random_leader(team):
	var team_list = team_random_list[team]
	var index = floor(randf() * team_list.size())
	var leader = team_list[index]
	team_list.remove(index)
	return leader


func leaders():
	var red_leaders = []
	var blue_leaders = []
	for team in autoload.teams:
		var counter = 0
		var leaders = game.player_choose_leaders
		if team != game.player_team: leaders = game.enemy_choose_leaders
		for leader in leaders:
			var leader_name = leader
			if leader == "random":
				leader_name = autoload.leaders.keys()[randi() % autoload.leaders.size()]
			var lane = game.map.lanes[0]
			if game.map.lanes.size() == 3:
				if counter < 2: lane = game.map.lanes[0]
				if counter == 2: lane = game.map.lanes[1]
				if counter > 2: lane = game.map.lanes[2]
			var path = game.maps.new_path(lane, team)
			var leader_node = game.maps.create(self[leader_name], lane, team, "point_random", path.start)
			leader_node.origin = path.start
			#send_leader(leader_node, path.follow)
			counter += 1
			if team == "red":
				red_leaders.append(leader_node)
			else:
				blue_leaders.append(leader_node)
	game.ui.get_node("score_board").initialize(red_leaders, blue_leaders)


func send_leader(leader, path):
	yield(get_tree(), "idle_frame")
	Behavior.follow.path(leader, path, "advance")


func pawns():
	spawn_group_cycle()


func spawn_group_cycle():
	Behavior.orders.lanes_cycle()
	Behavior.orders.leaders_cycle()
	Behavior.orders.update_taxes()
	
	for team in autoload.teams:
		var extra_unit = Behavior.orders.player_extra_unit
		if team != game.player_team: extra_unit = Behavior.orders.enemy_extra_unit
		for lane in game.map.lanes:
			send_pawn("archer", lane, team)
			for n in 2:
				send_pawn("infantry", lane, team)
			send_pawn(extra_unit, lane, team)
	
	timer.start()
	yield(timer, "timeout")
	Behavior.orders.leaders_cycle()
	
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
	var path = game.maps.new_path(lane, team)
	var pawn = recycle(template, lane, team, path.start)
	if not pawn:
		var unit_template = self[template]
		pawn = game.maps.create(unit_template, lane, team, "point_random", path.start)
	Behavior.orders.set_pawn(pawn)
	#Behavior.follow.path(pawn, path.follow, "advance")



func spawn_unit(unit, l, t, mode, point):
	unit.lane = l
	unit.team = t
	unit.dead = false
	unit.visible = true
	if mode == "point_random":
		point = game.utils.offset_point_random(point, 25)
	if mode == "random_map":
		point = game.utils.random_point()
	unit.global_position = point
	unit.set_state("idle")
	unit.set_behavior("stop")
	return unit


func next_to_building(template, building):
	var spawn_point = building.global_position
	if building.team == "blue": spawn_point.x -= game.map.tile_size
	else: spawn_point.x += game.map.tile_size
	var unit_template = self[template]
	return game.maps.create(unit_template, "", building.team, "point", spawn_point)


func cemitery_add_pawn(unit):
	var side = "player"
	if unit.team != game.player_team: side = "enemy"
	var index = side+"_"+unit.display_name
	cemitery[index].append(unit)


func cemitery_add_leader(leader):
	match leader.team:
		game.player_team:
			Behavior.spawn.cemitery.player_leaders.append(leader)
		game.enemy_team:
			Behavior.spawn.cemitery.enemy_leaders.append(leader)
	
	var respawn_time = order_time * leader.respawn
	yield(get_tree().create_timer(respawn_time), "timeout")
	
	# respawn leader
	var team = leader.team
	var lane = leader.lane
	var path = game.map.lanes_paths[leader.lane].duplicate()
	if leader.team == "red": path.invert()
	var start = path.pop_front()
	leader = spawn_unit(leader, lane, team, "point_random", start)
	leader.reset_unit()
	Behavior.follow.path(leader, path, "advance")
