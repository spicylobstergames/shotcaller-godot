tool extends Navigation2D

export var _update_building_navpolygons = false setget update_building_navpolygons
export var _update_terrain_colliders = false setget update_terrain_colliders

func _ready():
	if not Engine.editor_hint:
		visible = false

const MAP_BOUNDS = 1e8
#Go through all the buildings and add a collider for them
func get_polygon(shape: Shape2D) -> PoolVector2Array:
	if shape is CircleShape2D:
		var out_array = PoolVector2Array([])
		var segments = 10
		for i in range(segments):
			out_array.append(Vector2(1.0, 0.0).rotated(float(i) / float(segments) * TAU))
		for i in range(out_array.size()):
			out_array[i] *= shape.radius * 1.5
		return out_array
	if shape is RectangleShape2D:
		return PoolVector2Array([
			shape.extents * Vector2(-1.0, -1.0),
			shape.extents * Vector2(1.0, -1.0),
			shape.extents * Vector2(1.0, 1.0),
			shape.extents * Vector2(-1.0, 1.0),
		])
	else:
		push_error("Missing shape to polygon conversion for %s" % [shape])
		return PoolVector2Array([])
func update_building_navpolygons(_unused = null):
	if not Engine.editor_hint:
		return
	
	$FinalNavigationPolygonInstance.navpoly = $BaseNavigationPolygonInstance.navpoly.duplicate()
	
	for unit in get_tree().get_nodes_in_group("units"):
		var shape:Shape2D = unit.get_node("CollisionShape2D").shape
		var untransformed_polygon = get_polygon(shape)
		var transformed_polygon = PoolVector2Array([])
		for point in untransformed_polygon:
			transformed_polygon.append(unit.get_node("CollisionShape2D").global_transform.xform(point))
		
		$FinalNavigationPolygonInstance.navpoly.add_outline(transformed_polygon)
	$FinalNavigationPolygonInstance.navpoly.make_polygons_from_outlines()
# Use the base nav polygon to generate colliders for terrain
func update_terrain_colliders(_unused = null):
	if not Engine.editor_hint:
		return
	for child in $TerrainBlockers.get_children():
		child.queue_free()
	var navpoly = $BaseNavigationPolygonInstance.navpoly.duplicate()
	navpoly.add_outline(
		PoolVector2Array([
			Vector2(-MAP_BOUNDS,-MAP_BOUNDS),
			Vector2(MAP_BOUNDS,-MAP_BOUNDS),
			Vector2(MAP_BOUNDS,MAP_BOUNDS),
			Vector2(-MAP_BOUNDS,MAP_BOUNDS),
		])
	)
	navpoly.make_polygons_from_outlines()
	var vertices = navpoly.get_vertices()
	for i in range(navpoly.get_polygon_count()):
		var indices = navpoly.get_polygon(i)
		var new_polygon_collider = CollisionPolygon2D.new()
		var new_polygon = PoolVector2Array([])
		for index in indices:
			var point = vertices[index]
			new_polygon.append(point)
		$TerrainBlockers.add_child(new_polygon_collider)
		new_polygon_collider.set_owner(owner)
		new_polygon_collider.polygon = new_polygon

