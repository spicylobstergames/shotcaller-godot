extends Node2D


# self = game.map_manager


var current_map := "one_lane_map"

var one_lane_map:PackedScene = preload("res://map/maps/one_lane_map.tscn")
var three_lane_map:PackedScene = preload("res://map/maps/three_lane_map.tscn")
var rect_test_map:PackedScene = preload("res://map/maps/rect_test_map.tscn")


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
	Behavior.path.setup_pathfind()
	game.ui.map_loaded()
	game.map_loaded()


func setup_leaders(red_leaders, blue_leaders):
	var game = get_tree().get_current_scene()

	game.ui.scoreboard.build(red_leaders, blue_leaders)
	game.ui.leaders_icons.build()
	game.ui.inventories.build_leaders()
	game.ui.orders_panel.build_leaders()
	game.ui.active_skills.build_leaders()




func setup_lanes():
	for lane in WorldState.get_state("map").get_node("lanes").get_children():
		WorldState.get_state("lanes")[lane.name] = line_to_array(lane)
	
	Behavior.orders.build_lanes()


func line_to_array(line):
	# from PackedVector2Array to Array
	var array = []
	for point in line.points:
		array.append(point)
	return array


func setup_buildings():
	var game = get_tree().get_current_scene()

	for team in WorldState.get_state("map").get_node("buildings").get_children():
		for building in team.get_children():
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
	
	# shop
	game.ui.shop.blacksmiths = []
	if WorldState.get_state("map").has_node("buildings/blue/blacksmith"):
		game.ui.shop.blacksmiths.append( WorldState.get_state("map").get_node("buildings/blue/blacksmith") )
	if WorldState.get_state("map").has_node("buildings/red/blacksmith"):
		game.ui.shop.blacksmiths.append( WorldState.get_state("map").get_node("buildings/red/blacksmith") )
	
	# orders
	for neutral in WorldState.get_state("map").neutrals:
		if WorldState.get_state("map").has_node("buildings/blue/" + neutral):
			game.ui.orders_panel[neutral].append( WorldState.get_state("map").get_node("buildings/blue/" + neutral) )
		if WorldState.get_state("map").has_node("buildings/red/" + neutral):
			game.ui.orders_panel[neutral].append( WorldState.get_state("map").get_node("buildings/red/" + neutral) )
	
	game.ui.orders_panel.update()


func has_neutral_buildings(team):
	var neutral_buildings = false
	for neutral in WorldState.get_state("map").neutrals:
		var neutral_building = WorldState.get_state("map").get_node("buildings/"+team+"/"+neutral)
		if neutral_building.team == team:
			neutral_buildings = true
			break
	return neutral_buildings


func buildings_visibility(b):
	for team in WorldState.get_state("map").get_node("buildings").get_children():
		for building in team.get_children():
			building.visible = b
