extends Node

enum PeriodicTypeID {Increase, Decrease}

var _timers: Dictionary = {}


static func draw_line_circle(node: Node2D, radius, width: float, color: Color, maxerror = 0.25) -> void:

	if radius <= 0.0:
		return

	var maxpoints = 1024

	var numpoints = ceil(PI / acos(1.0 - maxerror / radius))
	numpoints = clamp(numpoints, 3, maxpoints)

	var points = PoolVector2Array([])

	for i in numpoints:
		var phi = i * PI * 2.0 / numpoints
		var v = Vector2(sin(phi), cos(phi))
		points.push_back(v * radius)
		
	points.push_back(points[1])

	node.draw_polyline(points, color, width)


func change_periodic(object: Object, prop_name: String, step_value: float, max_value: float, rate: float, delta: float, type: int = PeriodicTypeID.Increase) -> void:
	var key = "{0}_{1}".format([prop_name, object.get_instance_id()])
	
	if object.get(prop_name) == null:
		return
	
	if object.get(prop_name) >= max_value:
		object.set(prop_name, max_value)
		if _timers.has(key):
			_timers.erase(key)
		return
	
	if not _timers.has(key):
		#print(13, key)
		_timers[key] = rate
	
	_timers[key] -= get_physics_process_delta_time()

	if _timers[key] <= -0.0:
		match type:
			PeriodicTypeID.Increase:
				object.set(prop_name, object.get(prop_name) + step_value)
			PeriodicTypeID.Decrease:
				object.set(prop_name, object.get(prop_name) - step_value)
		
		_timers[key] = rate
