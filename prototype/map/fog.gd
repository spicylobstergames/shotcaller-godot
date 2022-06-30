extends TileMap
var game:Node

var tile_map_size:int
var trees:TileMap

var clear_skip:int = 16
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
	if clear_frame % clear_skip == 0 : cover_map()


func cover_map():
	for y in floor(tile_map_size):
		for x in floor(tile_map_size):
			game.map.fog.set_cell(x, y, 0)


# computes and caches 2d arrays with circle as booleans eg:
# 00100
# 01010
# 10001
# 01010
# 00100
var border_sight_mem:Dictionary = {}
var sight_mem:Dictionary = {}
func compute_sight(unit, border):
	var id = game.unit.modifiers.get_value(unit, "vision")
	if border:
		if id in border_sight_mem: return border_sight_mem[id]
	else:
		if id in sight_mem: return sight_mem[id]
	var a = []
	if id > 0:
		var rad = round(id/cell_size.x)
		for y in range(0, 2*rad):
			a.append([])
			for x in range(0, 2*rad):
				var r = Vector2(x-rad, y-rad)
				var d = r.length()
				if border:
					a[a.size()-1].append(d <= rad && d > rad - 1.5)
				else:
					a[a.size()-1].append(d <= rad)
	if border: border_sight_mem[id] = a
	else: sight_mem[id] = a
	return a


func clear_sigh_skip(unit):
	if clear_frame % clear_skip == 0 : clear_sight(unit)


func clear_sight(unit):
	if unit.team == game.player_team: 
		var id = game.unit.modifiers.get_value(unit, "vision")
		var rad = round(id/cell_size.x)
		var pos = world_to_map(unit.global_position)
		if id > 0:
			#if unit.type != "leader":
			var a = compute_sight(unit, false)
			for y in a.size():
				for x in a[y].size():
					if (a[y][x]): 
						var p = pos - Vector2(rad,rad) + Vector2(x,y)
						game.map.fog.set_cellv(p, -1)
		
		 # adds tree shadows
		
#			else:
#				var a = compute_sight(unit, true)
#				for y in a.size():
#					for x in a[y].size():
#						if (a[y][x]):
#							var p = pos - Vector2(rad,rad) + Vector2(x,y)
#							var line = game.unit.follow.path_finder.expandPath([[pos.x, pos.y], [p.x, p.y]])
#							var blocked = false
#							for point in line:
#								var point_pos = Vector2(point[0], point[1])
#								var tree = trees.get_cell(point[0]/3, point[1]/3)
#								if tree > 0: blocked = true
#								if not blocked: game.map.fog.set_cellv(point_pos, -1)
#			
#			adds sight angle limit
#			
#			if unit has sight angle:
#				var la = PI/6
#				var a = abs(game.utils.limit_angle(r.angle() - unit.angle))
#				if d > rad and a<la:
#					game.map.fog.set_cellv(pos + r, -1)


func hide_unit_skip(unit):
	if clear_frame % clear_skip == 0 : hide_unit(unit)


func hide_unit(unit):
	if behind_fog(unit) and not unit.type == "building":
		unit.modulate = Color.transparent
	else:
		unit.modulate = Color.white


func behind_fog(unit):
	var pos = world_to_map(unit.global_position)
	var fog = game.map.fog.get_cellv(pos)
	return fog == 0
