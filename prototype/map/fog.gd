extends TileMap
var game:Node

var tile_map_size:int
var trees:TileMap

var clear_skip:int = 10
var clear_frame:int = 0


func _ready():
	yield(get_tree(), "idle_frame")
	game = get_tree().get_current_scene()
	
	trees = get_node("../trees")
	
	var tile_size = game.map.get_node("tiles/ground").cell_size.x
# warning-ignore:narrowing_conversion
	tile_map_size = floor(game.map.size / tile_size)


func skip_start():
	clear_frame = (clear_frame + 1) % clear_skip
	if clear_frame%(clear_skip*2) == 0: cover_map()


var quarter = 0

func cover_map():
	if quarter == 0:
		for y in floor(tile_map_size/2):
			for x in floor(tile_map_size/2):
				game.map.fog.set_cell(x, y, 0)
	
	if quarter == 1:
		for y in range(floor(tile_map_size/2), tile_map_size):
			for x in floor(tile_map_size/2):
				game.map.fog.set_cell(x, y, 0)
	
	if quarter == 2:
		for y in tile_map_size:
			for x in range(floor(tile_map_size/2), tile_map_size):
				game.map.fog.set_cell(x, y, 0)
	
	if quarter == 3:
		for y in tile_map_size:
			for x in range(floor(tile_map_size/2), tile_map_size):
				game.map.fog.set_cell(x, y, 0)
				
	quarter = (quarter + 1) % 4


var sight_mem:Dictionary = {}

func compute_sight(unit):
	var id = unit.current_vision
	if id in sight_mem: return sight_mem[id]
	var a = []
	if unit.current_vision > 0:
		var rad = round(unit.current_vision/cell_size.x)
		for y in range(0, 2*rad):
			a.append([])
			for x in range(0, 2*rad):
				var r = Vector2(x-rad, y-rad)
				var d = r.length()
				a[a.size()-1].append(d < rad)
	sight_mem[id] = a
	return a


func clear_sigh_skip(unit):
	if clear_frame%clear_skip == 0:
		clear_sight(unit)


func clear_sight(unit):
	if unit.current_vision > 0:
		var rad = round(unit.current_vision/cell_size.x)
		var pos = world_to_map(unit.global_position)
		var a = compute_sight(unit)
		
		for y in a.size():
			for x in a[y].size():
				if (a[y][x]):
					var p = pos - Vector2(rad,rad) + Vector2(x,y)
					if (unit.type == "building"): 
						game.map.fog.set_cellv(p, -1)
					else: 
						if game.map.fog.get_cellv(p) >= 0:
							var line = game.unit.path.path_finder.expandPath([[pos.x, pos.y], [p.x, p.y]])
							var blocked = false
							for point in line:
								var tree = trees.get_cell(point[0]/3, point[1]/3)
								if tree > 0: 
									blocked = true
									
							if not blocked: game.map.fog.set_cellv(p, -1)
							
#				var la = PI/6
#				var a = abs(game.utils.limit_angle(r.angle() - unit.angle))
#				if d > rad and (unit.type == "building" or a<la):
#					game.map.fog.set_cellv(pos + r, -1)
