extends YSort
var game:Node

var unit_template:PackedScene = load("res://pawns/infantry.tscn")
var block_template:PackedScene = load("res://map/block.tscn")


var blocks

func _ready():
	game = get_tree().get_current_scene()
	blocks = get_node("blocks")


func setup_buildings():
	for team in get_node("buildings").get_children():
		for building in team.get_children():
			game.unit.reset_unit(building)
			game.unit.setup_selection(building)
			game.unit.path.setup_collisions(building)
			game.unit.setup_team(building)
			game.all_units.append(building)


func create(lane, team, mode, point):
	var unit = spawn(unit_template.instance(), lane, team, mode, point)
	game.get_node("map").add_child(unit)
	game.all_units.append(unit)
	return unit

func spawn(unit, l, t, mode, point):
	unit.lane = l
	unit.team = t
	unit.subtype = unit.name
	unit.dead = false
	unit.visible = true
	if mode == "point_random_no_coll":
		point = game.utils.point_random_no_coll(unit, point, 25)
	if mode == "random_no_coll":
		point = game.utils.random_no_coll(unit)
	unit.global_position = point
	game.unit.reset_unit(unit)
	game.unit.setup_team(unit)
	game.unit.setup_selection(unit)
	game.unit.path.setup_collisions(unit)
	game.unit.move.setup_timer(unit)
	game.minimap.setup_symbol(unit)
	unit.set_state("idle")
	unit.set_behavior("stop")
	return unit


