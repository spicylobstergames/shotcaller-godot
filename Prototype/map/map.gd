extends YSort
var game:Node

var blocks
var walls
var fog

var size:int = 2112

func _ready():
	game = get_tree().get_current_scene()
	
	walls = get_node("tiles/walls")
	fog = get_node("tiles/fog")
	blocks = get_node("blocks")


func setup_leaders():
	game.ui.inventories.build_leaders()
	game.unit.orders.build_leaders()


func setup_buildings():
	for team in get_node("buildings").get_children():
		for building in team.get_children():
			building.reset_unit()
			game.ui.minimap.setup_symbol(building)
			building.set_state("idle")
			building.set_behavior("stop")
			game.controls.setup_selection(building)
			game.unit.setup_collisions(building)
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
	
	game.controls.setup_selection(unit)
	game.unit.setup_collisions(unit)
	game.unit.move.setup_timer(unit)
	game.ui.minimap.setup_symbol(unit)
	if unit.type == "leader":
		if unit.team == game.player_team:
			game.player_leaders.append(unit)
		else:
			game.enemy_leaders.append(unit)
	return unit


