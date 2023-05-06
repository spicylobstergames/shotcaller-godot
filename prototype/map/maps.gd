extends Node2D
var game:Node


# self = game.maps


var current_map = "one_lane_map"

var one_lane_map:PackedScene = load("res://map/maps/one_lane_map.tscn")
var three_lane_map:PackedScene = load("res://map/maps/three_lane_map.tscn")
var rect_test_map:PackedScene = load("res://map/maps/rect_test_map.tscn")

@onready var spawn = $spawn
@onready var blocks = $blocks

func _ready():
	game = get_tree().get_current_scene()


func load_map(map_name):
	if game.map:
		game.map.hide()
		game.map.trees.light_mask = 0
	current_map = map_name
	game.map = self[map_name].instantiate()
	self.add_child(game.map)
	game.map.hide()
	create_container("unit_container")
	create_container("block_container")
	create_container("projectile_container")
	var mid = Vector2(game.map.size.x/2, game.map.size.y/2)
	WorldState.set_state("map_mid", mid)
	WorldState.set_state("map_camera_limit", game.map.camera_limit)
	WorldState.set_state("zoom_limit", game.map.zoom_limit)


func create_container(container_name):
	var container = Node2D.new()
	game.map.add_child(container)
	game.map.set(container_name, container)
	container.name = container_name


func map_loaded():
	game.map.fog.visible = game.map.fog_of_war
	#game.map.trees.light_mask = 2
	#game.map.walls.light_mask = 2
	
	
	
	setup_buildings()
	setup_lanes()
	blocks.setup_quadtree()
	game.ui.map_loaded()
	Behavior.path.setup_pathfind()
	game.map_loaded()


func setup_leaders(red_leaders, blue_leaders):
	game.ui.scoreboard.build(red_leaders, blue_leaders)
	game.ui.leaders_icons.build()
	game.ui.inventories.build_leaders()
	game.ui.orders_panel.build_leaders()
	game.ui.active_skills.build_leaders()


func new_path(lane, team):
	if lane in WorldState.lanes:
		var path = WorldState.lanes[lane].duplicate()
		if team == "blue" and game.map.has_node("buildings/red/castle"):
			path.append(game.map.get_node("buildings/red/castle").global_position)
		if team == "red" and game.map.has_node("buildings/blue/castle"): 
			path.invert()
			path.append(game.map.get_node("buildings/blue/castle").global_position)
		return path


func setup_lanes():
	for lane in game.map.get_node("lanes").get_children():
		WorldState.lanes[lane.name] = line_to_array(lane)
	
	Behavior.orders.build_lanes()


func line_to_array(line):
	# from PackedVector2Array to Array
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
			building.agent.set_state("lane", building.subtype)
			game.selection.setup_selection(building)
			game.collision.setup(building)
			if building.team == game.player_team:
				game.player_buildings.append(building)
			elif building.team == game.enemy_team:
				game.enemy_buildings.append(building)
			else: game.neutral_buildings.append(building)
			game.all_units.append(building)
			game.all_buildings.append(building)
	
	# shop
	game.ui.shop.blacksmiths = []
	if game.map.has_node("buildings/blue/blacksmith"):
		game.ui.shop.blacksmiths.append( game.map.get_node("buildings/blue/blacksmith") )
	if game.map.has_node("buildings/red/blacksmith"):
		game.ui.shop.blacksmiths.append( game.map.get_node("buildings/red/blacksmith") )
	
	# orders
	for neutral in game.map.neutrals:
		if game.map.has_node("buildings/blue/" + neutral):
			game.ui.orders_panel[neutral].append( game.map.get_node("buildings/blue/" + neutral) )
		if game.map.has_node("buildings/red/" + neutral):
			game.ui.orders_panel[neutral].append( game.map.get_node("buildings/red/" + neutral) )
	
	game.ui.orders_panel.update()


func create(template, lane, team, mode, point):
	var unit = template.instantiate()
	game.map.unit_container.add_child(unit)
	game.maps.spawn.spawn_unit(unit, lane, team, mode, point)
	unit.reset_unit()
	game.all_units.append(unit)
	game.selection.setup_selection(unit)
	game.collision.setup(unit)
	Behavior.move.setup_timer(unit) # collision reaction timer
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


func buildings_visibility(b):
	for team in game.map.get_node("buildings").get_children():
		for building in team.get_children():
			building.visible = b
