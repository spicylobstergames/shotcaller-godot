extends Position2D

export(bool) var enabled: bool = false setget set_enabled
export(NodePath) var _target: NodePath = ""
export(Array) var move_points: Array = []

export(int) var ray_count: int = 8
export(int) var radius: int = 30

var ai_path: GSAIPath

var _is_ready = false
var _rotation: float = 0.0
var avoid_direction: Vector2 = Vector2.ZERO
var target: PhysicsBody2D = null

var ray_directions = []
var interest_angle_directions = []
var avoid_angle_directions = []
var opposite_angle_direactions = []
var target_direction = Vector2.ZERO
var velocity = Vector2.ZERO
var avoid_distances = []

var space_state: Physics2DDirectSpaceState = null

func set_enabled(value: bool) -> void:
	enabled = value
	set_physics_process(enabled)
	set_physics_process_internal(enabled)


func _ready() -> void:
	if _target:
		target = get_node(_target)
		space_state = Physics2DServer.space_get_direct_state(target.get_world_2d().space)

	for i in range(ray_count):
		ray_directions.append(Vector2.ZERO)
		interest_angle_directions.append(0)
		avoid_angle_directions.append(0)
		avoid_distances.append(0)
		var angle = i * 2 * PI / ray_count
		ray_directions[i] = Vector2.RIGHT.rotated(angle)
	
	set_enabled(enabled)

	_is_ready = true


func _physics_process(delta: float) -> void:
	update()


func custom_calculate_steering(agent: GSAISteeringAgent, acceleration: GSAITargetAcceleration, prediction_time: float =  1.0, weight: float = 0.1) -> void:
	if target and _is_ready and enabled and move_points:
		_setup_ai_move_to_path(agent)
		if move_points.size() > 1:
			ai_path.create_path(move_points)
		
		var target_position = agent.position + (agent.linear_velocity * prediction_time)
		var target_distance: float = ai_path.calculate_distance(target_position)
		
		if ai_path.is_open and target_distance < ai_path.calculate_distance(agent.position):
			target_distance = ai_path.length
				
		var closest_position: Vector3 = ai_path.calculate_target_position(target_distance)
		avoid_direction = GSAIUtils.to_vector2(agent.position.direction_to(closest_position))
		
		_setup_interest_direction()
		_setup_target_didrection()
		_setup_avoid_direction()

		var desired_velocity = target_direction.rotated(global_rotation) #* agent.linear_speed_max
		velocity = velocity.linear_interpolate(desired_velocity, weight)
		global_rotation = velocity.angle()
		_rotation = global_rotation

		acceleration.linear = GSAIUtils.to_vector3(velocity.normalized())
		acceleration.linear *= agent.linear_acceleration_max


func _setup_target_didrection():
	for i in ray_count:
		if avoid_angle_directions[i] > 0.0:
			interest_angle_directions[i] = 0.0
	
	target_direction = Vector2.ZERO
	for i in ray_count:
		target_direction += (ray_directions[i] * interest_angle_directions[i])
	
	target_direction = target_direction.normalized() 


func _setup_interest_direction() -> void:
	var new_dir = avoid_direction if avoid_direction != Vector2.ZERO else transform.x
	for i in ray_count:
		var dot = ray_directions[i].rotated(_rotation).dot(new_dir) * 0.5 + 0.8
		interest_angle_directions[i] = max(0, dot)


func _setup_avoid_direction() -> void:
	for i in ray_count:
		var query = space_state.intersect_ray(
			global_position,
			global_position + ray_directions[i].rotated(_rotation) * radius, 
			[self, target],
			512
		)
		if query:
			var distance = global_position.distance_to(query.position)
			avoid_distances[i] = distance
		else:
			avoid_distances[i] = Vector2.ZERO
		avoid_angle_directions[i] = 1.0 if query else 0.0
	
	
func _draw() -> void:
	if false:#ProjectSettings.get("global/debug"):
		if target and _is_ready and enabled:
			for i in ray_count:
				draw_line(Vector2.ZERO, ray_directions[i] * radius * interest_angle_directions[i], Color.purple, 1.0)
			
			for i in ray_count:
				draw_line(Vector2.ZERO, ray_directions[i] * avoid_distances[i] * avoid_angle_directions[i], Color.crimson, 1.0)
			
			draw_line(Vector2.ZERO, target_direction * (radius + 50), Color.green, 1.0)


func _setup_ai_move_to_path(agent: GSAISteeringAgent) -> void:
	if not ai_path:
		ai_path = GSAIPath.new(
			[
				agent.position,
				agent.position
			],
			true
		)
