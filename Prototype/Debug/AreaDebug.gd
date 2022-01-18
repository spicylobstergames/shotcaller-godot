tool
extends Position2D

export(int) var radius = 50 setget set_radius
export(Color) var color = Color.white


func set_radius(value: int) -> void:
	radius = value
	if not Engine.editor_hint:
		update()


func _draw() -> void:
	if not Engine.editor_hint:
		_draw_area(radius)


func _draw_area(_radius, maxerror = 0.1) -> void:
	if _radius <= 0.0:
		return

	var maxpoints = 1024 # I think this is renderer limit

	var numpoints = ceil(PI / acos(1.0 - maxerror / _radius))
	numpoints = clamp(numpoints, 3, maxpoints)

	var points = PoolVector2Array([])

	for i in numpoints:
		var phi = i * PI * 2.0 / numpoints
		var v = Vector2(sin(phi), cos(phi))
		points.push_back(v * _radius)
	
	var first_point = points[0]
	first_point.x -= 0.5
	points.push_back(first_point)

	draw_polyline(points, color, 1.1, true)
