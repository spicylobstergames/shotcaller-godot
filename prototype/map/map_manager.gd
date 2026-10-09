extends Node2D

signal map_became_ready

# self = game.map_manager


var current_map := "one_lane_map"

var one_lane_map:PackedScene = preload("res://map/maps/one_lane_map.tscn")
var three_lane_map:PackedScene = preload("res://map/maps/three_lane_map.tscn")
var campaign_map:PackedScene = preload("res://map/maps/campaign_map.tscn")


func load_current_map():
	load_map(current_map)

func load_map(map_name):
	current_map = map_name
	var map = self[map_name].instantiate()
	self.add_child(map)
	WorldState.set_state("map", map)
	map.hide()
	var unit_container = create_container("unit_container")
	unit_container.y_sort_enabled = true
	var projectile_container = create_container("projectile_container")
	projectile_container.y_sort_enabled = true
	create_container("block_container")
	WorldState.set_state("map_size", map.size)
	var mid = Vector2(map.size.x/2, map.size.y/2)
	WorldState.set_state("lanes", {})
	WorldState.set_state("map_mid", mid)
	WorldState.set_state("map_camera_limit", map.camera_limit)
	WorldState.set_state("zoom_limit", map.zoom_limit)


func create_container(container_name):
	var container = Node2D.new()
	WorldState.get_state("map").add_child(container)
	WorldState.get_state("map").set(container_name, container)
	container.name = container_name
	return container


func map_loaded():
	var map = WorldState.get_state("map")
	var game = get_tree().get_current_scene()

	map.fog.visible = map.fog_of_war
	setup_buildings()
	setup_lanes()
	Collisions.setup_quadtree(map)
	Goap.navigation.setup_pathfind()
	game.ui.map_loaded()
	map_became_ready.emit()


func setup_leaders(red_leaders, blue_leaders):
	var game = get_tree().get_current_scene()

	game.ui.scoreboard.build(red_leaders, blue_leaders)
	game.ui.leaders_icons.build()
	game.ui.inventories.build_leaders()
	game.ui.orders_panel.leaders_built.connect(
		Goap.get_goal("WalkLane").build_leaders, CONNECT_ONE_SHOT
	)
	game.ui.orders_panel.build_leaders()
	game.ui.active_skills.build_leaders()




func setup_lanes():
	var map = WorldState.get_state("map")
	var lanes_node = map.get_node_or_null("lanes")
	if lanes_node:
		for lane in lanes_node.get_children():
			WorldState.get_state("lanes")[lane.name] = line_to_array(lane)

	Goap.get_action("ChooseTarget").build_lane_priorities(
		lanes_node.get_children() if lanes_node else []
	)


func line_to_array(line):
	var array = []
	for point in line.points:
		array.append(point)
	return array


func setup_buildings():
	var game = get_tree().get_current_scene()

	var map = WorldState.get_state("map")
	var buildings_node = map.get_node_or_null("buildings")
	if buildings_node:
		for team in buildings_node.get_children():
			for building in team.get_children():
				Collisions.setup(building)
				building.reset_unit()
				game.ui.minimap.setup_symbol(building)
				building.set_state("idle")
				building.agent.set_state("lane", building.subtype)
				game.selection.setup_selection(building)
				Collisions.setup(building)
				if building.team == WorldState.get_state("player_team"):
					WorldState.get_state("player_buildings").append(building)
				elif building.team == WorldState.get_state("enemy_team"):
					WorldState.get_state("enemy_buildings").append(building)
				else: WorldState.get_state("neutral_buildings").append(building)
				WorldState.get_state("all_units").append(building)
				WorldState.get_state("all_buildings").append(building)
	
	game.ui.shop.blacksmiths = []
	var blue_blacksmith = map.get_node_or_null("buildings/blue/blacksmith")
	if blue_blacksmith:
		game.ui.shop.blacksmiths.append(blue_blacksmith)
	var red_blacksmith = map.get_node_or_null("buildings/red/blacksmith")
	if red_blacksmith:
		game.ui.shop.blacksmiths.append(red_blacksmith)
	
	for neutral in WorldState.get_state("map").neutrals:
		var blue_neutral = map.get_node_or_null("buildings/blue/" + neutral)
		if blue_neutral:
			game.ui.orders_panel[neutral].append(blue_neutral)
		var red_neutral = map.get_node_or_null("buildings/red/" + neutral)
		if red_neutral:
			game.ui.orders_panel[neutral].append(red_neutral)
	
	game.ui.orders_panel.update()


func has_neutral_buildings(team):
	var neutral_buildings = false
	var map = WorldState.get_state("map")
	for neutral in map.neutrals:
		var neutral_building = map.get_node_or_null("buildings/"+team+"/"+neutral)
		if neutral_building and neutral_building.team == team:
			neutral_buildings = true
			break
	return neutral_buildings


func buildings_visibility(b):
	var map = WorldState.get_state("map")
	var buildings_node = map.get_node_or_null("buildings")
	if buildings_node:
		for team in buildings_node.get_children():
			for building in team.get_children():
				building.visible = b
