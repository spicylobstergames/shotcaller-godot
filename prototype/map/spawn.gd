extends Node

var game:Node


# self = game.maps.spawn


var order_time = 8
var lumberjack_cost = 1

var infantry:PackedScene = load("res://pawns/infantry.tscn")
var archer:PackedScene = load("res://pawns/archer.tscn")
var mounted:PackedScene = load("res://pawns/mounted.tscn")

var lumberjack:PackedScene = load("res://neutrals/lumberjack.tscn")
var mailboy:PackedScene = load("res://neutrals/mailboy.tscn")

var arthur:PackedScene = load("res://leaders/arthur.tscn")
var bokuden:PackedScene = load("res://leaders/bokuden.tscn")
var hongi:PackedScene = load("res://leaders/hongi.tscn")
var joan:PackedScene = load("res://leaders/joan.tscn")
var lorne:PackedScene = load("res://leaders/lorne.tscn")
var nagato:PackedScene = load("res://leaders/nagato.tscn")
var osman:PackedScene = load("res://leaders/osman.tscn")
var raja:PackedScene = load("res://leaders/raja.tscn")
var robin:PackedScene = load("res://leaders/robin.tscn")
var rollo:PackedScene = load("res://leaders/rollo.tscn")
var sida:PackedScene = load("res://leaders/sida.tscn")
var takoda:PackedScene = load("res://leaders/takoda.tscn")
var tomyris:PackedScene = load("res://leaders/tomyris.tscn")

var player_extra_unit = "infantry"
var enemy_extra_unit = "infantry"

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

@onready var timer:Timer = $timer

func _ready():
	game = get_tree().get_current_scene()
	
	#await get_tree().idle_frame
	
	timer.one_shot = true
	timer.wait_time = order_time


func start():
	if game.test.debug:
		game.test.spawn_unit()
	else: 
		pawns()
		await get_tree().create_timer(4).timeout
		leaders()


func random_leader(team):
	var team_list = team_random_list[team]
	var index = floor(randf() * team_list.size())
	var leader = team_list[index]
	team_list.remove(index)
	return leader


func leaders():
	var red_leaders = []
	var blue_leaders = []
	for team in WorldState.teams:
		var counter = 0
		var choose_leaders = game.player_choose_leaders
		if team != game.player_team: choose_leaders = game.enemy_choose_leaders
		for leader in choose_leaders:
			var leader_name = leader
			if leader == "random":
				leader_name = WorldState.leaders.keys()[randi() % WorldState.leaders.size()]
			var lane = "mid"
			if game.map.get_node("lanes").get_children().size() == 3:
				if counter < 2: lane = "top"
				if counter == 2: lane = "mid"
				if counter > 2: lane = "bot"
			var path = game.maps.new_path(lane, team)
			var path_start = path.pop_front()
			var leader_node = game.maps.create(self[leader_name], lane, team, "point_random", path_start)
			Behavior.path.setup_unit_path(leader_node, path)
			leader_node.setup_leader_exp()
			if team == "red":
				red_leaders.append(leader_node)
			else:
				blue_leaders.append(leader_node)
			counter += 1
	
	game.maps.setup_leaders(red_leaders, blue_leaders)


func pawns():
	spawn_group_cycle()


func spawn_group_cycle():
	Behavior.orders.lanes_cycle()
	Behavior.orders.leaders_cycle()
	Behavior.orders.update_taxes()
	
	for team in WorldState.teams:
		var extra_unit = player_extra_unit
		if team != game.player_team: extra_unit = enemy_extra_unit
		for lane in game.map.get_node("lanes").get_children():
			send_pawn("archer", lane.name, team)
			for n in 2:
				send_pawn("infantry", lane.name, team)
			send_pawn(extra_unit, lane.name, team)
	
	timer.start()
	await timer.timeout
	Behavior.orders.leaders_cycle()
	
	timer.start()
	await timer.timeout
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
	var path_start = path.pop_front()
	var pawn = recycle(template, lane, team, path_start)
	if not pawn:
		var unit_template = self[template]
		pawn = game.maps.create(unit_template, lane, team, "point_random", path_start)
	Behavior.path.setup_unit_path(pawn, path)
	Behavior.orders.set_pawn(pawn)


func spawn_unit(unit, lane, team, mode, point):
	unit.agent.set_state("lane", lane)
	unit.setup_team(team)
	unit.dead = false
	unit.show()
	if mode == "point_random":
		point = Utils.offset_point_random(point, 25)
	if mode == "random_map":
		point = Utils.random_point()
	unit.global_position = point
	unit.set_state("idle")
	return unit


func next_to_building(template, building, team):
	var spawn_point = building.global_position
	spawn_point.y += building.collision_radius + building.collision_position.y + 1
	var unit_template = self[template]
	var new_team = team
	if not team: new_team = building.team
	return game.maps.create(unit_template, "", new_team, "point", spawn_point)


func cemitery_add_pawn(unit):
	var side = "player"
	if unit.team != game.player_team: side = "enemy"
	var index = side+"_"+unit.display_name
	cemitery[index].append(unit)


func cemitery_add_leader(leader):
	match leader.team:
		game.player_team:
			cemitery.player_leaders.append(leader)
		game.enemy_team:
			cemitery.enemy_leaders.append(leader)
	
	var respawn_time = order_time * leader.respawn
	await get_tree().create_timer(respawn_time).timeout
	
	# respawn leader
	var team = leader.team
	var lane = leader.agent.get_state("lane")
	var path = WorldState.lanes[lane].duplicate()
	if leader.team == "red": path.reverse()
	var path_start = path.pop_front()
	leader = spawn_unit(leader, lane, team, "point_random", path_start)
	leader.reset_unit()



# LUMBERMILL

func lumberjack_hire(lumbermill, team):
	var unit = lumbermill.agent.get_state("lumberjack")
	if not unit: # create lumberjack
		unit = next_to_building("lumberjack", lumbermill, team)
		unit.agent.set_state("lumbermill", lumbermill)  
		unit.agent.set_state("deliver_position", unit.global_position)
		var closest_tree = lumbermill.get_node("closest_tree")
		unit.agent.set_state("closest_tree", closest_tree.global_position)
		lumbermill.agent.set_state("lumberjack", unit)
	
	unit.setup_team(team)
	unit.show()
	
	# charge player
	var team_leaders = game.player_leaders
	if team == game.enemy_team: team_leaders = game.enemy_leaders
	for leader in team_leaders: leader.gold -= floor(lumberjack_cost/team_leaders.size())


# CAMP

func camp_hire(unit, team):
	if team == game.player_team:
		player_extra_unit = unit
	else: enemy_extra_unit = unit
	
	var cost
	match unit:
		"infantry": cost = 1
		"archer": cost = 2
		"mounted": cost = 3
	
	var team_leaders = game.player_leaders
	if team == game.enemy_team: team_leaders = game.enemy_leaders
	for leader in team_leaders: leader.gold -= cost
