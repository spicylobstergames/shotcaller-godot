extends YSort
var game:Node

var unit_template:PackedScene = load("res://units/creeps/melee.tscn")

var quad:_QuadTreeClass

func _ready():
	game = get_tree().get_current_scene()
	var bound = Rect2(Vector2.ZERO, Vector2(game.size,game.size))
	quad = create_quadtree(bound, 16, 8)


func spawn(l, t, point):
	var unit = unit_template.instance()
	unit.subtype = unit.name
	unit.lane = l
	unit.team = t
	unit.global_position = point
	setup_unit(unit)
	setup_selection(unit)
	setup_collisions(unit)
	game.ui.setup_symbol(unit)
	unit.get_node("animations").current_animation = "idle"
	game.get_node("map").add_child(unit)
	return unit


func setup_unit(unit):
	unit.current_hp = unit.hp
	unit.current_vision = unit.vision
	unit.current_speed = unit.speed
	unit.current_damage = unit.damage
	game.all_units.append(unit)



func setup_collisions(unit):
	unit.selection_rad = unit.get_node("collisions/select").shape.radius
	unit.collision_rad = unit.get_node("collisions/block").shape.radius
	if unit.has_node("collisions/attack"):
		unit.attack_hit_position = unit.get_node("collisions/attack").position
		unit.attack_hit_radius = unit.get_node("collisions/attack").shape.radius
	

func setup_selection(unit):
	if unit.selectable: game.selectable_units.append(unit)


func setup_buildings():
	for team in get_node("buildings").get_children():
		for building in team.get_children():
			setup_unit(building)
			setup_selection(building)
			setup_collisions(building)


func create_quadtree(bounds, splitThreshold, splitLimit, currentSplit = 0):
	return _QuadTreeClass.new(self, bounds, splitThreshold, splitLimit, currentSplit)



class _QuadTreeClass:
	
	var _bounds = Rect2(Vector2.ZERO, Vector2.ONE)
	var _splitThreshold = 10
	var _maxSplits = 5
	var _curSplit = 0
	var _bodies = []
	var _quadrants = []
	var _drawMat = null
	var _node = null


	func _init(node, bounds, splitThreshold, maxSplits, currentSplit = 0):
		_node = node
		_bounds = bounds
		_splitThreshold = splitThreshold
		_maxSplits = maxSplits
		_curSplit = currentSplit


	func clear():
		for quadrant in _quadrants:
			quadrant.clear()
		_bodies.clear()
		_quadrants.clear()


	func add_body(body):
		# Adds a body to the QuadTree
			
		if(_quadrants.size() != 0):
			var quadrant = _get_quadrant(body.global_position)
			quadrant.add_body(body)
		else:
			_bodies.append(body)
			if(_bodies.size() > _splitThreshold && _curSplit < _maxSplits):
				_split()


	func get_bodies_in_radius(center, radius):
		var result = []
		_get_bodies_in_radius(center, radius, result)
		return result


	func _get_bodies_in_radius(center, radius, result):
		if(_quadrants.size() == 0):
			for body in _bodies:
				result.append(body)
		else:
			for quadrant in _quadrants:
				if(quadrant._contains_circle(center, radius)):
					quadrant._get_bodies_in_radius(center, radius, result)


	func _contains_circle(center, radius):
		var bound_center = (_bounds.position + _bounds.end) / 2
		var bound_half = _bounds.size / 2
		var d = (center - bound_center).abs()
		if d.x > bound_half.x + radius: return false
		if d.y > bound_half.y + radius: return false
		if d.x <= bound_half.x: return true
		if d.y <= bound_half.y: return true
		return (d - bound_half).length() <= radius;


	func _split():
		# Splits the QuadTree into 4 quadrants and disperses its bodies
		var sz =  _bounds.size / 2

		var aBounds = Rect2(_bounds.position, sz)
		var bBounds = Rect2(Vector2(_bounds.position.x + sz.x, _bounds.position.y), sz)
		var cBounds = Rect2(Vector2(_bounds.position.x + sz.x, _bounds.position.y + sz.y), sz)
		var dBounds = Rect2(Vector2(_bounds.position.x, _bounds.position.y + sz.y), sz)
		
		var splitNum = _curSplit + 1
		
		_quadrants.append(_node.create_quadtree(aBounds, _splitThreshold, _maxSplits, splitNum))
		_quadrants.append(_node.create_quadtree(bBounds, _splitThreshold, _maxSplits, splitNum))
		_quadrants.append(_node.create_quadtree(cBounds, _splitThreshold, _maxSplits, splitNum))
		_quadrants.append(_node.create_quadtree(dBounds, _splitThreshold, _maxSplits, splitNum))

		for body in _bodies:
			var quadrant = _get_quadrant(body.global_position)
			quadrant.add_body(body)
		_bodies.clear()


	func _get_quadrant(location):
		# Gets the quadrant a Vector2 location lies in
		if(location.x > _bounds.position.x + _bounds.size.x / 2):
			if(location.y > _bounds.position.y + _bounds.size.y / 2):
				return _quadrants[2]
			else:
				return _quadrants[1]
		else:
			if(location.y > _bounds.position.y + _bounds.size.y / 2): 
				return _quadrants[3]
			return _quadrants[0]
		pass
	
	
	func get_rect_lines():
		# Gets all rect line points of this quadrant and its children
		var points = []
		_get_rect_lines(points)
		return points


	func _get_rect_lines(points):
		for quadrant in _quadrants:
			quadrant._get_rect_lines(points)
			
		var p1 = Vector3(_bounds.position.x, _bounds.position.y, 1)
		var p2 = Vector3(p1.x + _bounds.size.x, p1.y, 1)
		var p3 = Vector3(p1.x + _bounds.size.x, p1.y + _bounds.size.y, 1)
		var p4 = Vector3(p1.x, p1.y + _bounds.size.y, 1)
		points.append(p1)
		points.append(p2)
		
		points.append(p2)
		points.append(p3)
		
		points.append(p3)
		points.append(p4)
		
		points.append(p4)
		points.append(p1)
