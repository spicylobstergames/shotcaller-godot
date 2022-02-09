extends Skill

var direct_space_state: Physics2DDirectSpaceState

var queued_casts = 0
export var damage: float
export var attack_range: float
func _ready():
	._ready()
	direct_space_state = agent.get_world_2d().direct_space_state
	
func cast():
	var super_result = .cast()
	if super_result:
		queued_casts += 1
	return super_result
	
func _physics_process(delta):
	for _i in range(queued_casts):
		var shape = CircleShape2D.new()
		shape.radius = attack_range
		var shape_query = Physics2DShapeQueryParameters.new()
		shape_query.collide_with_areas = false
		shape_query.collide_with_bodies = true
		shape_query.collision_layer = 1 << 8
		shape_query.exclude = []
		shape_query.margin = 0.0
		shape_query.motion = Vector2(0.0,0.0)
		shape_query.set_shape(shape)
		shape_query.transform = agent.transform
		
		var results = direct_space_state.intersect_shape(
			shape_query
		)
		for result in results:
			var target_attributes = result.collider.get_node("Attributes")
			var agent_attributes = agent.get_node("Attributes")
			if target_attributes.primary.unit_team != agent_attributes.primary.unit_team:
				target_attributes.stats.emit_signal("change_property", "health", target_attributes.stats.health - damage, funcref(result.collider, "_on_attributes_stats_changed"))
			
	queued_casts = 0

func get_range():
	return attack_range
