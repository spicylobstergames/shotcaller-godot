tool extends Navigation2D

export var grow_amount = 1.0 setget update_grow_amount

export var _update_building_navpolygons = false setget update_building_navpolygons
export var _update_terrain_colliders = false setget update_terrain_colliders

func _ready():
	if not Engine.editor_hint:
		visible = false

const MAP_BOUNDS = 1e5
#Go through all the buildings and add a collider for them
func get_polygon(shape: Shape2D) -> PoolVector2Array:
	if shape is CircleShape2D:
		var out_array = PoolVector2Array([])
		var segments = 10
		for i in range(segments):
			out_array.append(Vector2(1.0, 0.0).rotated(float(i) / float(segments) * TAU))
		for i in range(out_array.size()):
			out_array[i] *= shape.radius
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

class MergePolygonsResult:
	var polygons: Array = []
	var done = false
	func _init(_polygons, _done):
		polygons = _polygons
		done = _done


#Checks if point is in the array
func is_point_in_polygon(point: Vector2, polygon: PoolVector2Array) -> bool:
	for polygon_point in polygon:
		if polygon_point.distance_to(point) < 10.0:
			return true
	return false


func are_polygons_equal(polygon1: PoolVector2Array, polygon2: PoolVector2Array) -> bool:
	if polygon1.size() != polygon2.size():
		return false
	var found_points = 0
	for i in range(polygon1.size()):
		if is_point_in_polygon(polygon1[i], polygon2):
			found_points += 1
	return found_points == polygon1.size()

func is_polygon_in_polygon_array(polygon: PoolVector2Array, array: Array):
	for array_polygon in array:
		if are_polygons_equal(polygon, array_polygon):
			return true
	return false

func are_polygon_arrays_equal(array1: Array, array2: Array) -> bool:
	if array1.size() != array2.size():
		return false
	for polygon in array1:
		if not is_polygon_in_polygon_array(polygon, array2):
			return false
	return true
		

func merge_polygons(polygons: Array) -> MergePolygonsResult:
	var out_polygons = polygons.duplicate()
	for i in range(0, polygons.size()):
		for j in range(i+1, polygons.size()):
			if Geometry.clip_polygons_2d(polygons[j], polygons[i]) == []:
				continue
			var merged_polygons = Geometry.merge_polygons_2d(polygons[i], polygons[j])
#			if compare_polygon_arrays([polygons[j], polygons[i]], merged_polygons):
#			print(are_polygon_arrays_equal([polygons[j], polygons[i]], merged_polygons))

#			print(merged_polygons)
#			print([polygons[j], polygons[i]])
			if not are_polygon_arrays_equal([polygons[j], polygons[i]], merged_polygons):
				out_polygons.erase(polygons[i])
				out_polygons.erase(polygons[j])
				out_polygons.append_array(merged_polygons)
				return MergePolygonsResult.new(out_polygons, false)
	return MergePolygonsResult.new(out_polygons, true)

func update_building_navpolygons(_unused = null):
	if not Engine.editor_hint:
		return
	
#	$FinalNavigationPolygonInstance.navpoly = $BaseNavigationPolygonInstance.navpoly.duplicate()
	$FinalNavigationPolygonInstance.navpoly = NavigationPolygon.new()

	var inflated_polygons = []
	for outline in $BaseNavigationPolygonInstance.navpoly.outlines:
		inflated_polygons.append_array(Geometry.offset_polygon_2d(outline, grow_amount))
	
	var combined_polygons = []
	for unit in get_tree().get_nodes_in_group("units"):
		var shape:Shape2D = unit.get_node("CollisionShape2D").shape
		var untransformed_polygon = get_polygon(shape)
		
		var transformed_polygon = PoolVector2Array([])
		for point in untransformed_polygon:
			transformed_polygon.append(unit.get_node("CollisionShape2D").global_transform.xform(point))
		inflated_polygons.append_array(Geometry.offset_polygon_2d(transformed_polygon, grow_amount))
	while true:
		var merge_result: MergePolygonsResult = merge_polygons(inflated_polygons)
		if merge_result.done:
			combined_polygons = merge_result.polygons
			break
		else:
			inflated_polygons = merge_result.polygons
#	$FinalNavigationPolygonInstance.navpoly.make_polygons_from_outlines()


	for polygon in combined_polygons:
		$FinalNavigationPolygonInstance.navpoly.add_outline(polygon)

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


func update_grow_amount(new_grow_amount):
	grow_amount = new_grow_amount
	update_building_navpolygons()
