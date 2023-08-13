extends Node

var game:Node


# self = game.spawn

var time = 8
var lumberjack_cost = 1

# var mailboy:PackedScene = load("res://neutrals/mailboy.tscn")

var cemitery = {
	"player_infantry": [],
	"enemy_infantry": [],
	"player_archer": [],
	"enemy_archer": [],
	"player_mounted": [],
	"enemy_mounted": [],
	"player_leaders": [],
	"enemy_leaders": [],
	"player_worker": [],
	"enemy_worker": []
}

var team_random_list = {"red": [], "blue": []}

func _ready():
	game = get_tree().get_current_scene()


func start():
	if game.test.debug:
		game.test.spawn_unit()
	else: 
		spawn_group_cycle()
		leaders()


func create(template, lane, team, mode, point):
	var unit = template.instantiate()
	WorldState.get_state("map").unit_container.add_child(unit)
	spawn_unit(unit, lane, team, mode, point)
	unit.reset_unit()
	WorldState.get_state("all_units").append(unit)
	game.selection.setup_selection(unit)
	Collisions.setup(unit)
	Behavior.move.setup_timer(unit) # collision reaction timer
	game.ui.minimap.setup_symbol(unit)
	if unit.type == "leader":
		WorldState.get_state("all_leaders").append(unit)
		if team == WorldState.get_state("player_team"):
			WorldState.get_state("player_leaders").append(unit)
		else:
			WorldState.get_state("enemy_leaders").append(unit)
	return unit


func leader_scene(leader_name):
	return load("res://leaders/"+leader_name+".tscn")


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
		var choose_leaders = WorldState.get_state("player_leaders_names")
		if team != WorldState.get_state("player_team"): choose_leaders = WorldState.get_state("enemy_leaders_names")
		for leader in choose_leaders:
			var leader_name = leader
			if leader == "random":
				leader_name = WorldState.leaders_list.keys()[randi() % WorldState.leaders_list.size()]
			var lane = "mid"
			if WorldState.get_state("map").get_node("lanes").get_children().size() == 3:
				if counter < 2: lane = "top"
				if counter == 2: lane = "mid"
				if counter > 2: lane = "bot"
			var path = Behavior.path.new_lane_path(lane, team)
			var path_start = path.pop_front()
			var leader_node = game.spawn.create(leader_scene(leader_name), lane, team, "point_random", path_start)
			Behavior.path.setup_unit_path(leader_node, path)
			leader_node.setup_leader_exp()
			if team == "red":
				red_leaders.append(leader_node)
			else:
				blue_leaders.append(leader_node)
			counter += 1
	
	game.map_manager.setup_leaders(red_leaders, blue_leaders)


func spawn_group_cycle():
	Behavior.orders.lanes_cycle()
	Behavior.orders.leaders_cycle()
	Behavior.orders.update_taxes()
	
	for team in WorldState.teams:
		var extra_unit = WorldState.get_state("player_extra_unit")
		if team != WorldState.get_state("player_team"): extra_unit = WorldState.get_state("enemy_extra_unit")
		for lane in WorldState.get_state("map").get_node("lanes").get_children():
			send_pawn("archer", lane.name, team)
			for n in 2:
				send_pawn("infantry", lane.name, team)
			send_pawn(extra_unit, lane.name, team)
	
	WorldState.spawn_timer.start()
	await WorldState.spawn_timer.timeout
	Behavior.orders.leaders_cycle()
	
	WorldState.spawn_timer.start()
	await WorldState.spawn_timer.timeout
	spawn_group_cycle()


func recycle(template, lane, team, point):
	var side = "player_"
	if team == WorldState.get_state("enemy_team"): side = "enemy_"
	var index = side+template
	if cemitery[index].size():
		var unit = cemitery[index].pop_back()
		unit = spawn_unit(unit, lane, team, "point_random", point)
		unit.reset_unit()
		return unit



func pawn_scene(pawn_name):
	return load("res://pawns/"+pawn_name+".tscn")


func send_pawn(template_name, lane, team):
	var path = Behavior.path.new_lane_path(lane, team)
	var path_start = path.pop_front()
	var pawn = recycle(template_name, lane, team, path_start)
	if not pawn:
		pawn = game.spawn.create(pawn_scene(template_name), lane, team, "point_random", path_start)
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
	var new_team = team
	if not team: new_team = building.team
	return game.spawn.create(template, "", new_team, "point", spawn_point)
	
	
func cemitery_add_worker(unit):
	var side = "player"
	if unit.team == WorldState.get_state("enemy_team"): side = "enemy"
	var index = side+"_"+unit.display_name
	cemitery[index].append(unit)


func cemitery_add_pawn(unit):
	var side = "player"
	if unit.team == WorldState.get_state("enemy_team"): side = "enemy"
	var index = side+"_"+unit.display_name
	cemitery[index].append(unit)


func cemitery_add_leader(leader):
	var player_team = WorldState.get_state("player_team")
	var enemy_team = WorldState.get_state("enemy_team")
	match leader.team:
		player_team:
			cemitery.player_leaders.append(leader)
		enemy_team:
			cemitery.enemy_leaders.append(leader)
	
	var respawn_time = time * leader.respawn
	await get_tree().create_timer(respawn_time).timeout
	
	# respawn leader
	var team = leader.team
	var lane = leader.agent.get_state("lane")
	var path = WorldState.get_state("lanes")[lane].duplicate()
	if leader.team == "red": path.reverse()
	var path_start = path.pop_front()
	leader = spawn_unit(leader, lane, team, "point_random", path_start)
	leader.reset_unit()



# LUMBERMILL

func neutral_scene(neutral_name):
	var neutral = load("res://neutrals/"+neutral_name+".tscn")
	WorldState.get_state("neutral_units").append(neutral)
	return neutral


func lumberjack_hire(lumbermill, team):
	var unit = lumbermill.agent.get_state("lumberjack")
	if not unit: # create lumberjack
		unit = next_to_building(neutral_scene("lumberjack"), lumbermill, team)
		unit.agent.set_state("lumbermill", lumbermill)  
		unit.agent.set_state("deliver_position", unit.global_position)
		var closest_tree = lumbermill.get_node("closest_tree")
		unit.agent.set_state("closest_tree", closest_tree.global_position)
		lumbermill.agent.set_state("lumberjack", unit)
	
	unit.setup_team(team)
	unit.show()
	
	# charge player
	var team_leaders = WorldState.get_state("player_leaders")
	if team == WorldState.get_state("enemy_team"): team_leaders = WorldState.get_state("enemy_leaders")
	for leader in team_leaders: leader.gold -= floor(lumberjack_cost/team_leaders.size())


# CAMP

func camp_hire(unit, team):
	if team == WorldState.get_state("player_team"):
		WorldState.set_state("player_extra_unit", unit)
	else: WorldState.set_state("enemy_extra_unit", unit)
	
	var cost
	match unit:
		"infantry": cost = 1
		"archer": cost = 2
		"mounted": cost = 3
	
	var team_leaders = WorldState.get_state("player_leaders")
	if team == WorldState.get_state("enemy_team"): team_leaders = WorldState.get_state("enemy_leaders")
	for leader in team_leaders: leader.gold -= cost
