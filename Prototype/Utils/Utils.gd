extends Node
class_name Utils






static func draw_line_circle(node: Node2D, radius, width: float, color: Color, maxerror = 0.25) -> void:

	if radius <= 0.0:
		return

	var maxpoints = 1024 # I think this is renderer limit

	var numpoints = ceil(PI / acos(1.0 - maxerror / radius))
	numpoints = clamp(numpoints, 3, maxpoints)

	var points = PoolVector2Array([])

	for i in numpoints:
		var phi = i * PI * 2.0 / numpoints
		var v = Vector2(sin(phi), cos(phi))
		points.push_back(v * radius)
		
	points.push_back(points[1])

	node.draw_polyline(points, color, width)
