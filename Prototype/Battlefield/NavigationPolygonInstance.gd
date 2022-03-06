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

var worker_thread: Thread

func tile_to_key(tile_index: int, is_collider = false) -> int:
	match tile_index:
		0:
			return 0
		1:
			return 1
		2:
			if is_collider:
				return 1
			else:
				return 0
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
			if vertex_to_check.distance_to(vertex) < 1.0:
				return true
		return false
	
	func find(searched_vertex: Vector2) -> int:
		for i in range(vertices.size()):
			if searched_vertex.distance_to(vertices[i]) < 1.0:
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

func is_inside_building(point: Vector2) -> bool:
	var test_shape = CircleShape2D.new()
	test_shape.radius = 8.0
	var test_shape_transform = Transform2D(0.0, point)
	for unit in get_tree().get_nodes_in_group("units"):
		var shape: Shape2D = unit.get_node("CollisionShape2D").shape
		if shape.collide(unit.get_node("CollisionShape2D").global_transform,test_shape,test_shape_transform):
			return true
	return false

func is_inside_specific_building(building: Node2D, point: Vector2) -> bool:
	var test_shape = CircleShape2D.new()
	test_shape.radius = 8.0
	var test_shape_transform = Transform2D(0.0, point)
	var shape: Shape2D = building.get_node("CollisionShape2D").shape
	return shape.collide(building.get_node("CollisionShape2D").global_transform,test_shape,test_shape_transform)

func _ready():
	update_navmap()
	worker_thread = Thread.new()

#func _physics_process(delta):
#	if not worker_thread.is_alive():
#		worker_thread.start(self, "worker_thread_call_navmap")

func _exit_tree():
	worker_thread.wait_to_finish()

func worker_thread_call_navmap(_unused):
	update_navmap()

func update_navmap():
	
	var tilemap: TileMap = get_parent().get_node("TileMap")

	var nav_polygon = NavigationPolygon.new()

	var tilemap_rect = tilemap.get_used_rect()
	var new_position = tilemap.map_to_world(tilemap_rect.position)
	var new_end = tilemap.map_to_world(tilemap_rect.end)
	tilemap_rect = Rect2(new_position, Vector2(0,0))
	tilemap_rect.end = new_end
	
	var vertex_dict = VertexDictionary.new()
	var indices = []
	
	var collider_vertex_dict = VertexDictionary.new()
	var collider_indices = []

	
	var step_size = 8.0
	var offset = 4.0
	
	#Generate polygons from static units
	for unit in get_tree().get_nodes_in_group("units"):
		var unit_vertex_dict = VertexDictionary.new()
		var unit_indices = []
		
		var x = tilemap_rect.position.x + offset
		while x < tilemap_rect.end.x + offset:
			var y = tilemap_rect.position.y + offset
			while y < tilemap_rect.end.y + offset:
				var top_left = int(is_inside_specific_building(unit, Vector2(x,y)))
				var top_right = int(is_inside_specific_building(unit, Vector2(x,y) + Vector2(step_size, 0.0)))
				var bottom_left = int(is_inside_specific_building(unit, Vector2(x,y) + Vector2(0.0, step_size)))
				var bottom_right = int(is_inside_specific_building(unit, Vector2(x,y) + Vector2(step_size, step_size)))
				
				var edge_indices = marching_squares_lut[[top_left,top_right,bottom_right,bottom_left]]
#				if edge_indices != []:
#					print(edge_indices)
				for edge in edge_indices:
					var edge_position = (edge_index_to_vec(edge) * 8.0 + Vector2(x,y))
#					print(edge_position)
					if unit_vertex_dict.has_vertex(edge_position):
						unit_indices.append(unit_vertex_dict.find(edge_position))
					else:
						unit_indices.append(unit_vertex_dict.vertices.size())
						unit_vertex_dict.vertices.append(edge_position)
				
				y += step_size
			x += step_size
		var line_combiner = LineCombiner.new()
		for i in range(0, unit_indices.size(), 2):
			var new_line = IndexLine.new(unit_indices[i], unit_indices[i + 1])
			line_combiner.lines.append(new_line)
		
		while line_combiner.lines.size() > 0:
			if line_combiner.current_polygon.size() <= 0:
				line_combiner.current_polygon.append(line_combiner.lines[0])
				line_combiner.lines.remove(0)
			line_combiner.add_connecting_line(0)
		if not line_combiner.current_polygon.empty():
			line_combiner.polygons.append(line_combiner.current_polygon)
		for polygon in line_combiner.polygons:
			var line_indices = []
			for line in polygon:
				line_indices.append(line.b)
			
			var points = []
			for index in line_indices:
				points.append(unit_vertex_dict.vertices[index])
			nav_polygon.add_outline(PoolVector2Array(points))
	
	#"Expand" the tilemap with NavBlockers so units don't get stuck on the edges
	var x = tilemap_rect.position.x + offset
	while x < tilemap_rect.end.x + offset:
		var y = tilemap_rect.position.y + offset
		while y < tilemap_rect.end.y + offset:
			var map_coordinates = tilemap.world_to_map(Vector2(x, y))
			
			for i in range(-1, 2):
				for j in range(-1, 2):
					var tile_value = tilemap.get_cellv(map_coordinates + Vector2(i, j))
					if tile_value == 0 and tilemap.get_cellv(map_coordinates) == 1:
						tilemap.set_cellv(map_coordinates, 2)
			
			y += step_size
		x += step_size
	
	
	#Generate the lines for navmesh and colliders
	x = tilemap_rect.position.x + offset
	while x < tilemap_rect.end.x + offset:
		var y = tilemap_rect.position.y + offset
		while y < tilemap_rect.end.y + offset:
			var map_coordinates = tilemap.world_to_map(Vector2(x, y))
			
			var top_left = tile_to_key(tilemap.get_cellv(map_coordinates))
			var top_right = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(1.0,0.0)))
			var bottom_left = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(0.0, 1.0)))
			var bottom_right = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(1.0,1.0)))
			
			var collider_top_left = tile_to_key(tilemap.get_cellv(map_coordinates), true)
			var collider_top_right = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(1.0,0.0)), true)
			var collider_bottom_left = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(0.0, 1.0)), true)
			var collider_bottom_right = tile_to_key(tilemap.get_cellv(map_coordinates + Vector2(1.0,1.0)), true)
			
			var edge_indices = marching_squares_lut[[top_left,top_right,bottom_right,bottom_left]]
			
			for edge in edge_indices:
				var edge_position = (edge_index_to_vec(edge) * 8.0 + Vector2(x,y))
				if vertex_dict.has_vertex(edge_position):
					indices.append(vertex_dict.find(edge_position))
				else:
					indices.append(vertex_dict.vertices.size())
					vertex_dict.vertices.append(edge_position)
			var collider_edge_indices = marching_squares_lut[[collider_top_left,collider_top_right,collider_bottom_right,collider_bottom_left]]
			
			for edge in collider_edge_indices:
				var edge_position = (edge_index_to_vec(edge) * 8.0 + Vector2(x,y))
				if collider_vertex_dict.has_vertex(edge_position):
					collider_indices.append(collider_vertex_dict.find(edge_position))
				else:
					collider_indices.append(collider_vertex_dict.vertices.size())
					collider_vertex_dict.vertices.append(edge_position)
			y += step_size
		x += step_size

	var line_combiner = LineCombiner.new()
	for i in range(0, indices.size(), 2):
		var new_line = IndexLine.new(indices[i], indices[i + 1])
		line_combiner.lines.append(new_line)
	
	while line_combiner.lines.size() > 0:
		if line_combiner.current_polygon.size() <= 0:
			line_combiner.current_polygon.append(line_combiner.lines[0])
			line_combiner.lines.remove(0)
		line_combiner.add_connecting_line(0)
	if not line_combiner.current_polygon.empty():
		line_combiner.polygons.append(line_combiner.current_polygon)
	
	for polygon in line_combiner.polygons:
		var line_indices = []
		for line in polygon:
			line_indices.append(line.b)
		
		var points = []
		for index in line_indices:
			points.append(vertex_dict.vertices[index])
		nav_polygon.add_outline(PoolVector2Array(points))
	
	for i in range(0, collider_indices.size(), 2):
		var static_body = StaticBody2D.new()
		get_tree().get_nodes_in_group("battlefield")[0].add_child(static_body)
		static_body.collision_layer = 512
		var collision_shape = CollisionShape2D.new()
		var segment_shape = SegmentShape2D.new()
		collision_shape.shape = segment_shape
		segment_shape.a = collider_vertex_dict.vertices[collider_indices[i]]
		segment_shape.b = collider_vertex_dict.vertices[collider_indices[i+1]]
		static_body.add_child(collision_shape)
	
	nav_polygon.make_polygons_from_outlines()
	#print(nav_polygon.polygons.size())
	navpoly = nav_polygon

