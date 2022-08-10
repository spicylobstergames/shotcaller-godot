extends Node2D
var game:Node

var current_map = '1lane_map'

func _ready():
	game = get_tree().get_current_scene()


func load_map(map_name):
	current_map = map_name
	game.map = game.maps.get_node(map_name)
	game.get_node('maps').visible = true
	game.ui.minimap.update_map_texture = true


func map_loaded():
	game.map.fog.visible = game.map.fog_of_war
	game.ui.buttons_update()
	game.ui.show_all()
	game.start()


func setup_leaders():
	game.ui.leaders_icons.build()
	game.ui.leaders_icons.show()
	game.ui.inventories.build_leaders()
	game.ui.orders.build_leaders()
	game.unit.orders.build_leaders()


func new_path(lane, team):
	var path = game.map.lanes_paths[lane].duplicate()
	if team == "blue": path.append(game.map.red_castle.global_position)
	if team == "red": 
		path.invert()
		path.append(game.map.blue_castle.global_position)
	var start = path.pop_front()
	return {
		"start": start,
		"follow": path
	}


func setup_lanes():
	for lane in game.map.lanes:
		var line = game.map.get_node("lanes/"+ lane)
		game.map.lanes_paths[lane] = line_to_array(line)
	
	game.unit.orders.build_lanes()


func line_to_array(line):
	# from PoolVector2Array to Array
	var array = []
	for point in line.points:
		array.append(point)
	return array

func setup_buildings():
	for team in game.map.get_node("buildings").get_children():
		for building in team.get_children():
			building.reset_unit()
			game.ui.minimap.setup_symbol(building)
			building.set_state("idle")
			building.set_behavior("stop")
			game.selection.setup_selection(building)
			game.collision.setup(building)
			if building.team == game.player_team:
				game.player_buildings.append(building)
			elif building.team == game.enemy_team:
				game.enemy_buildings.append(building)
			else: game.neutral_buildings.append(building)
			game.all_units.append(building)
			game.all_buildings.append(building)


func create(template, lane, team, mode, point):
	var unit = game.unit.spawn.spawn_unit(template.instance(), lane, team, mode, point)
	game.map.add_child(unit)
	unit.reset_unit()
	game.all_units.append(unit)
	game.selection.setup_selection(unit)
	game.collision.setup(unit)
	game.unit.move.setup_timer(unit)
	game.ui.minimap.setup_symbol(unit)
	if unit.type == "leader":
		if team == game.player_team:
			game.player_leaders.append(unit)
		else:
			game.enemy_leaders.append(unit)
	return unit



func has_neutral_buildings(team):
	var neutral_buildings = false
	for neutral in game.map.neutrals:
		var neutral_building = game.map.get_node("buildings/"+team+"/"+neutral)
		if neutral_building.team == team:
			neutral_buildings = true
			break
	return neutral_buildings
