extends YSort
var game:Node

const _QuadtreeGD = preload("tool/quadtree.gd")
const _GridGD = preload("pathfind/grid.gd")
const _JumpPointFinderGD = preload("pathfind/jump_point_finder.gd")

var unit_template:PackedScene = load("res://pawns/infantry.tscn")

var quad
var path_grid
var path_finder

func _ready():
	game = get_tree().get_current_scene()
	setup_quadtree()
	setup_pathfind()



func setup_quadtree():
	var Quad = _QuadtreeGD.new()
	var bound = Rect2(Vector2.ZERO, Vector2(game.size,game.size))
	quad = Quad.create_quadtree(bound, 16, 16)


func setup_pathfind():
	# get tiles
	var walls = get_node("tiles/walls")
	var walls_rect = walls.get_used_rect()
	var walls_size =  walls_rect.size
	#setup grid
	var Grid = _GridGD.new().Grid
	path_grid = Grid.new(walls_size.x, walls_size.y)
	# add blocked tiles
	for cell in walls.get_used_cells():
		path_grid.setWalkableAt(cell.x, cell.y, false)
	# setup finder
	var Jpf = _JumpPointFinderGD.new().JumpPointFinder
	path_finder = Jpf.new()


func find_path(g1, g2):
	var cell_size = 64
	var p1 = Vector2(floor(g1.x / cell_size), floor(g1.y / cell_size))
	var p2 = Vector2(floor(g2.x / cell_size), floor(g2.y / cell_size))
	if in_limits(p1) and in_limits(p2): 
		return path_finder.findPath(p1.x, p1.y, p2.x, p2.y, path_grid)
	else: return []


func in_limits(p):
	return ((p.x > 0 and p.y > 0) and (p.x < path_grid.width and p.y < path_grid.height)) 

func setup_team(unit):
	var is_red = unit.team == "red"
	
	if unit.type == "pawn":
		unit.mirror_toggle(is_red)
		if not is_red:
				var texture = unit.get_texture()
				texture.sprite.material = null



func setup_buildings():
	for team in get_node("buildings").get_children():
		for building in team.get_children():
			setup_unit(building)
			setup_selection(building)
			setup_collisions(building)
			setup_team(building)
	for block in get_node("blocks").get_children():
		setup_collisions(block)
		game.all_units.append(block)

func create(lane, team, point):
	var unit = spawn(unit_template.instance(), lane, team, point)
	game.get_node("map").add_child(unit)
	game.all_units.append(unit)

func spawn(unit, l, t, point):
	unit.lane = l
	unit.team = t
	unit.subtype = unit.name
	unit.dead = false
	unit.visible = true
	setup_team(unit)
	unit.global_position = point
	setup_unit(unit)
	setup_selection(unit)
	setup_collisions(unit)
	setup_timer(unit)
	game.minimap.setup_symbol(unit)
	unit.get_node("animations").current_animation = "idle"
	return unit


func setup_unit(unit):
	unit.current_hp = unit.hp
	unit.current_vision = unit.vision
	unit.current_speed = unit.speed
	unit.current_damage = unit.damage


func setup_collisions(unit):
	if unit.has_node("collisions/select"):
		unit.selection_position = unit.get_node("collisions/select").position
		unit.selection_radius = unit.get_node("collisions/select").shape.radius
	
	if unit.has_node("collisions/block"):
		unit.collision_position = unit.get_node("collisions/block").position
		unit.collision_radius = unit.get_node("collisions/block").shape.radius
	
	if unit.has_node("collisions/attack"):
		unit.attack_hit_position = unit.get_node("collisions/attack").position
		unit.attack_hit_radius = unit.get_node("collisions/attack").shape.radius
	

func setup_selection(unit):
	if unit.selectable: game.selectable_units.append(unit)


func setup_timer(unit):
	unit.collision_timer = Timer.new()
	unit.collision_timer.one_shot = true
	unit.add_child(unit.collision_timer)


