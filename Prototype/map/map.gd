extends YSort
var game:Node

var blocks
var walls
var fog

var size:int = 2112

const tile_size = 64
const half_tile_size = tile_size / 2

var lanes:Array = ["bot", "mid", "top"]

var top:Array
var mid:Array
var bot:Array


func _ready():
	game = get_tree().get_current_scene()
	
	walls = get_node("tiles/walls")
	fog = get_node("tiles/fog")
	blocks = get_node("blocks")


func setup_lanes():
	var top_line = game.map.get_node("lanes/top")
	var mid_line = game.map.get_node("lanes/mid")
	var bot_line = game.map.get_node("lanes/bot")
	
	top = line_to_array(top_line)
	mid = line_to_array(mid_line)
	bot = line_to_array(bot_line)
	
	game.unit.orders.build_lanes()


func new_path(lane, team):
	var path = game.map[lane].duplicate()
	if team == "red": path.invert()
	var start = path.pop_front()
	return {
		"start": start,
		"follow": path
	}


func setup_leaders():
	game.ui.inventories.build_leaders()
	game.ui.orders.setup_leaders()
	game.unit.orders.build_leaders()
	game.ui.leaders_icons.textures()



func line_to_array(line):
	# from PoolVector2Array to Array
	var array = []
	for point in line.points:
		array.append(point)
	return array



func setup_buildings():
	for team in get_node("buildings").get_children():
		for building in team.get_children():
			building.reset_unit()
			game.ui.minimap.setup_symbol(building)
			building.set_state("idle")
			building.set_behavior("stop")
			game.selection.setup_selection(building)
			game.collision.setup(building)
			if building.team == game.player_team:
				game.player_buildings.append(building)
			else:
				game.enemy_buildings.append(building)
			game.all_units.append(building)


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


