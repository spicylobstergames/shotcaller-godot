extends Node
var game:Node


# COLLISION QUADTREES
const _QuadtreeGD = preload("../map/tool/quadtree.gd")
var quad


# PATHFIND GRID
const _GridGD = preload("../map/pathfind/grid.gd")
const _JumpPointFinderGD = preload("../map/pathfind/jump_point_finder.gd")
var path_grid
var path_finder



func _ready():
	game = get_tree().get_current_scene()


func create_block(x, y):
	var block = game.map.block_template.instance()
	block.selectable = false
	block.moves = false
	block.attacks = true
	block.collide = true
	block.global_position = Vector2(32 + x * 64, 32 + y * 64)
	game.map.blocks.add_child(block)
	setup_collisions(block)
	game.all_units.append(block)


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


func setup_quadtree():
	var Quad = _QuadtreeGD.new()
	var bound = Rect2(Vector2.ZERO, Vector2(game.size,game.size))
	quad = Quad.create_quadtree(bound, 16, 16)


func setup_pathfind():
	# get tiles
	var walls = game.map.get_node("tiles/walls")
	var walls_rect = walls.get_used_rect()
	var walls_size =  walls_rect.size
	#setup grid
	var Grid = _GridGD.new().Grid
	path_grid = Grid.new(walls_size.x, walls_size.y)
	# add blocked tiles
	for cell in walls.get_used_cells():
		game.unit.path.create_block(cell.x, cell.y)
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


func follow(unit, path, cb):
	if path and path.size():
		var next_point = path.pop_front()
		unit.current_path = path
		game.unit[cb].start(unit, next_point)


func follow_next(unit):
	follow(unit, unit.current_path, unit.behavior)
