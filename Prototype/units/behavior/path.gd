extends Node
var game:Node



# PATHFIND GRID
const _GridGD = preload("../../map/pathfind/grid.gd")
const _JumpPointFinderGD = preload("../../map/pathfind/jump_point_finder.gd")
var path_grid
var path_finder



func _ready():
	game = get_tree().get_current_scene()


func setup_pathfind():
	# get tiles
	var walls_rect = game.map.walls.get_used_rect()
	var walls_size =  walls_rect.size
	#setup grid
	var Grid = _GridGD.new().Grid
	path_grid = Grid.new(walls_size.x, walls_size.y)
	# add blocked tiles
	for cell in game.map.walls.get_used_cells():
		game.map.blocks.create_block(cell.x, cell.y)
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
