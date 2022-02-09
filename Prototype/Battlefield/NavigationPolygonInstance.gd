extends NavigationPolygonInstance

var test_marker = preload("res://Debug/TestMarker.tscn")
export var draw_debug_symbols = false
# Edge indices lookup table
var marching_squares_lut = {
	[0,0,0,0]: [],
	[0,0,0,1]: [2,3],
	[0,0,1,0]: [1,2],
	[0,0,1,1]: [3,1],
	[0,1,0,0]: [0,1],
	[0,1,0,1]: [0,1,2,3],
	[0,1,1,0]: [0,2],
	[0,1,1,1]: [3,0],
	[1,0,0,0]: [3,0],
	[1,0,0,1]: [0,2],
	[1,0,1,0]: [3,0,1,2],
	[1,0,1,1]: [0,1],
	[1,1,0,0]: [3,1],
	[1,1,0,1]: [1,2],
	[1,1,1,0]: [2,3],
	[1,1,1,1]: [],
}



func tile_to_key(tile_index: int) -> int:
	match tile_index:
		0:
			return 0
		1:
			return 1
		_: 
			return 0

func edge_index_to_vec(index:int) -> Vector2:
	var out_vec
	match index:
		0:
			out_vec = Vector2(0.5, 0.0)
		1:
			out_vec = Vector2(1.0, 0.5)
		2:
			out_vec = Vector2(0.5, 1.0)
		3:
			out_vec = Vector2(0.0, 0.5)
		_:
			push_error("Invalid edge index")
			out_vec = Vector2(1.0,1.0)
	return out_vec * 1.0

class VertexDictionary:
	var vertices = []
	
	func has_vertex(vertex_to_check: Vector2) -> bool:
		for vertex in vertices:
			if vertex_to_check.distance_to(vertex) < 5:
				return true
		return false
	
	func find(searched_vertex: Vector2) -> int:
		for i in range(vertices.size()):
			if searched_vertex.distance_to(vertices[i]) < 5:
				return i
		return -1

class IndexLine:
	#Line made up of indices
	var a: int
	var b: int

	func _init(_first:int, _second:int):
		a = _first
		b = _second
	func swap():
		return IndexLine.new(b,a)

class LineCombiner:
	
	var lines = []
	var polygons = []
	var current_polygon = []
	
	enum ConnectedResult{
		Left,
		Right,
		LeftSwap,
		RightSwap,
		Same,
		Not
	}
	func are_lines_connected(first: IndexLine, second: IndexLine) -> int:
#		var first = lines[first_index]
#		var second = lines[second_index]
		
		if first.a == second.b:
			return ConnectedResult.Left
		elif first.b == second.a:
			return ConnectedResult.Right
		if first.a == second.a:
			return ConnectedResult.LeftSwap
		elif first.b == second.b:
			return ConnectedResult.RightSwap
		elif first.a == second.a and first.b == second.b:
			return ConnectedResult.Same
		elif first.b == second.a and first.a == second.b:
			return ConnectedResult.Same
		else:
			return ConnectedResult.Not
	func add_connecting_line(compared_line_polygon_index: int):
		var compared_line = current_polygon[compared_line_polygon_index]
		var i = 0
		for line in lines:
			match are_lines_connected(compared_line, line):
				ConnectedResult.Left:
					current_polygon.insert(compared_line_polygon_index, line)
					lines.remove(i)
					return
				ConnectedResult.Right:
					current_polygon.insert(compared_line_polygon_index + 1, line)
					lines.remove(i)
					return
				ConnectedResult.LeftSwap:
					current_polygon.insert(compared_line_polygon_index, line.swap())
					lines.remove(i)
					return
				ConnectedResult.RightSwap:
					current_polygon.insert(compared_line_polygon_index + 1, line.swap())
					lines.remove(i)
					return
			i += 1
		polygons.append(current_polygon)
		current_polygon = []
		
func _ready():
	var tilemap: TileMap = get_parent().get_node("TileMap")
	
	var tilemap_rect = tilemap.get_used_rect()
	var new_position = tilemap.map_to_world(tilemap_rect.position)
	var new_end = tilemap.map_to_world(tilemap_rect.end)
	tilemap_rect = Rect2(new_position, Vector2(0,0))
	tilemap_rect.end = new_end
	
	var vertex_dict = VertexDictionary.new()
	var indices = []
#	for x in range(tilemap_rect.position.x,tilemap_rect.size.x):
#		for y in range(tilemap_rect.position.y,tilemap_rect.size.y):
	
	var step_size = 8.0
	var offset = 4.0
	
	
	var x = tilemap_rect.position.x + offset
	while x < tilemap_rect.end.x + offset:
		var y = tilemap_rect.position.y + offset
		while y < tilemap_rect.end.y + offset:
#			print("x: %s, y: %s is %s" % [x,y, tilemap.get_cell(x,y)])			
			var map_coordinates = tilemap.world_to_map(Vector2(x, y))
			
			var top_left = tile_to_key(tilemap.get_cellv(map_coordinates))
			var top_right = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(1.0,0.0)))
			var bottom_left = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(0.0, 1.0)))
			var bottom_right = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(1.0,1.0)))
			
			var edge_indices = marching_squares_lut[[top_left,top_right,bottom_right,bottom_left]]
			
			if draw_debug_symbols:
				var new_marker = test_marker.instance()
				new_marker.global_position = Vector2(x,y)
				new_marker.modulate.r *= top_left
				get_parent().call_deferred("add_child", new_marker)
				
				var center_marker = test_marker.instance()
				center_marker.global_position = Vector2(x - offset,y - offset)
				center_marker.modulate = Color.green
				get_parent().call_deferred("add_child", center_marker)
			
			var debug_points = []
			for edge in edge_indices:
				var edge_position = (edge_index_to_vec(edge) * 8.0 + Vector2(x,y))
				if vertex_dict.has_vertex(edge_position):
					indices.append(vertex_dict.find(edge_position))
				else:
					indices.append(vertex_dict.vertices.size())
					vertex_dict.vertices.append(edge_position)
				if draw_debug_symbols:
					debug_points.append(edge_position)
					var edge_marker = test_marker.instance()
					edge_marker.global_position = edge_position
					edge_marker.modulate = Color.red
					get_parent().call_deferred("add_child", edge_marker)
			if draw_debug_symbols:
				for point_index in range(0, debug_points.size(),2):
					var new_line = Line2D.new()
					new_line.width = 0.5
					new_line.points = [
						debug_points[point_index],
						debug_points[point_index + 1]
					]
					get_parent().call_deferred("add_child", new_line)
			
			y += step_size
		x += step_size
	
	var nav_polygon = NavigationPolygon.new()

	var line_combiner = LineCombiner.new()
	for i in range(0, indices.size(), 2):
		var new_line = IndexLine.new(indices[i], indices[i + 1])
		line_combiner.lines.append(new_line)
	
	while line_combiner.lines.size() > 0:
		if line_combiner.current_polygon.size() <= 0:
			line_combiner.current_polygon.append(line_combiner.lines[0])
			line_combiner.lines.remove(0)
		line_combiner.add_connecting_line(0)
	
	
	for polygon in line_combiner.polygons:
		var line_indices = []
		for line in polygon:
			line_indices.append(line.b)
		
		var points = []
		for index in line_indices:
			points.append(vertex_dict.vertices[index])
		nav_polygon.add_outline(PoolVector2Array(points))
	
	nav_polygon.make_polygons_from_outlines()
	navpoly = nav_polygon

