extends KinematicBody2D

signal dead(unit)
signal respawn(unit)

export(Units.TeamID) var team: int = Units.TeamID.None setget set_team
export(Texture) var blue_team_texture: Texture
export(Texture) var red_team_texture: Texture

var _is_ready: bool = false
var is_selected: bool = false setget set_is_selected
var move_position = Vector2.ZERO
var move_points: PoolVector2Array = PoolVector2Array()
var target_radius = 10
var av = Vector2.ZERO
var avoid_weight = 0.5
var velocity = Vector2.ZERO
var is_dead = false

var targeted_location: Vector2 = Vector2.ZERO
var targeted_enemy: KinematicBody2D = null
var targeted_ally: KinematicBody2D = null

var detected_units: Dictionary = {}


var ai_accel: GSAITargetAcceleration = GSAITargetAcceleration.new()
var ai_agent: GSAIKinematicBody2DAgent = GSAIKinematicBody2DAgent.new(self, GSAIKinematicBody2DAgent.MovementType.COLLIDE)
var ai_target_location: GSAIAgentLocation

var shape = Physics2DShapeQueryParameters.new()
var circle_shape = CircleShape2D.new()

onready var space_state = get_world_2d().direct_space_state


onready var attributes: Node = $Attributes
onready var stats: Node = $Stats
onready var sprite: Sprite = $TextureContainer/Sprite
onready var texture_container: Position2D = $TextureContainer
onready var behavior_animplayer: AnimationPlayer = $BehaviorAnimPlayer
onready var ability_animplayer: AnimationPlayer = $AbilityAnimPlayer
onready var state_debug: Label = $HUD/StateDebug
onready var healthbar: Control = $HUD/HealthBar


func set_is_selected(value: bool) -> void:
	is_selected = value
	if not Engine.editor_hint and _is_ready:
		sprite.material.set_shader_param("aura_width", int(value))


func set_team(value: int) -> void:
	team = value
	if _is_ready:
		_setup_team()
		
	
func _ready() -> void:
	_is_ready = true
	set_physics_process(false)
	set_team(team)
	_setup_spawn()



func _physics_process(_delta: float) -> void:
	velocity = GSAIUtils.to_vector2(ai_agent.linear_velocity)
	if attributes.stats.health <= 0:
		_setup_dead()
	else:
		var enemies = Units.get_enemies(
				self,
				team,
				Units.TypeID.Creep,
				[Units.TypeID.Creep, Units.TypeID.Leader, Units.TypeID.Building],
				Units.DetectionTypeID.Area,
				attributes.radius.unit_detection
				)
		
		$Blackboard.set_data("enemies", enemies)
		
		var allies = Units.get_allies(
				self,
				team,
				Units.TypeID.Creep,
				[Units.TypeID.Creep, Units.TypeID.Leader, Units.TypeID.Building],
				Units.DetectionTypeID.Area,
				attributes.radius.unit_detection
				)
		$Blackboard.set_data("allies", allies)

#		$Blackboard.set_data("state_behavior", attributes.state.behavior)
#		$Blackboard.set_data("state_action", attributes.state.action)
#		$Blackboard.set_data("state_reaction", attributes.state.reaction)


func _draw() -> void:
	if ProjectSettings.get("global/debug"):
		Utils.draw_line_circle(self, attributes.radius.attack_range, 1.0, Color.blue)
		Utils.draw_line_circle(self, attributes.radius.collision_size, 1.0, Color.orangered)
		Utils.draw_line_circle(self, attributes.radius.unit_detection, 1.0, Color.goldenrod)


func _setup_state_debug(text: String) -> void:
	state_debug.text = text


func _setup_face_direction(target_position: Vector2) -> void:
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction.x < 0:
		texture_container.scale.x = -1
		return
	texture_container.scale.x = 1


func _setup_ai_agent() -> void:
	ai_agent.linear_speed_max = attributes.stats.move_speed
	ai_agent.linear_acceleration_max = attributes.stats.move_acceleration
	ai_agent.linear_velocity = GSAIUtils.to_vector3(Vector2.ZERO)
	ai_agent.bounding_radius = attributes.radius.collision_size
	ai_agent.linear_drag_percentage = 0.0
	ai_agent.zero_linear_speed_threshold = 0.1


func _setup_radius_collision() -> void:
	$CollisionShape2D.shape.radius = attributes.radius.collision_size
	$UnitSelector/CollisionShape2D.shape.radius = attributes.radius.area_selection
	$UnitDetector/CollisionShape2D.shape.radius = attributes.radius.unit_detection


func _setup_team() -> void:
	attributes.primary.unit_team = team
	if blue_team_texture != null and red_team_texture != null:
		match team:
			Units.TeamID.Blue:
				sprite.texture = blue_team_texture
			Units.TeamID.Red:
				sprite.texture = red_team_texture


func _setup_healthbar() -> void:
	healthbar.set_max_health(attributes.stats.max_health)
	healthbar.set_health(attributes.stats.health)
	healthbar.set_max_mana(attributes.stats.max_mana)
	healthbar.set_mana(attributes.stats.mana)


func _setup_blackboard() -> void:
	$Blackboard.set_data("is_dead", false)
	$Blackboard.set_data("stats_health", attributes.stats.health)
	$Blackboard.set_data("stats_mana", attributes.stats.mana)
	$Blackboard.set_data("enemies", [])
	$Blackboard.set_data("allies", [])
	$Blackboard.set_data("buildings", [])
	$Blackboard.set_data("targeted_enemy", null)
	$Blackboard.set_data("target_end_point", global_position)
	$Blackboard.set_data("state_action", Units.ActionStateID.None)
	$Blackboard.set_data("state_reaction", Units.ReactionStateID.None)
	$Blackboard.set_data("state_behavior", Units.BehaviorStateID.None)


#func _setup_units_detector() -> void:
#	shape.set_shape(circle_shape)
#	shape.exclude = [self]
#	shape.collide_with_bodies = true
#	shape.collision_layer = 256
#	circle_shape.radius = stats.area_attack_range
#
#	if $Blackboard.has_data("allies"):
#		shape.exclude.append_array($Blackboard.get_data("allies"))
	
	

#func _setup_update_units_detector() -> void:
#	var query = space_state.intersect_shape(shape, 5)
#	print(query)
#	if $Blackboard.has_data("allies"):
#		shape.exclude.append_array($Blackboard.get_data("allies"))
#	if query:
#		var enemies = []
#		for e in query:
#			if e is KinematicBody2D:
#				enemies.append(e.collider)
#		$Blackboard.set_data(
#			"enemies",
#			enemies
#		)
#
#	var ci_rid = VisualServer.canvas_item_create()
#	VisualServer.canvas_item_set_parent(ci_rid, get_canvas_item())
#	var circle_shape = VisualServer.canvas_item_add_circle(ci_rid, Vector2.ZERO, 30, Color(1.0, 0.0, 0.0, 0.2))
#	intersect_point_on_canvas(point: Vector2, canvas_instance_id: int, max_results: int = 32, exclude: Array = [  ], collision_layer: int = 0x7FFFFFFF, collide_with_bodies: bool = true, collide_with_areas: bool = false)


func _setup_dead() -> void:
	set_physics_process(false)
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	$HitArea.collision_mask = 0
	$UnitDetector.collision_mask = 0
	$UnitSelector.collision_layer = 0
	$BehaviorTree.is_active = false
	$Blackboard.set_data("is_dead", is_dead)
	emit_signal("dead", self)

	if behavior_animplayer.has_animation("Dead") and behavior_animplayer.current_animation != "Dead":
		behavior_animplayer.play("Dead")

	yield(behavior_animplayer, "animation_finished")
	position.y = global_position.y - 1000


func _setup_spawn() -> void:
	is_dead = false
#	stats.stats_health = 100
#	stats.stats_max_health = 100
	collision_layer = 256
	collision_mask = 768
	$HitArea.collision_mask = 65536
	$UnitSelector.collision_layer = 256
	$UnitDetector.collision_mask = 256
	$BehaviorTree.is_active = true
	$BehaviorTree.start()
	
	for p in attributes.stats._saved_init_properties.keys():
		attributes.stats.set(p, attributes.stats._saved_init_properties[p])
	
	set_team(team)
	_setup_healthbar()
	_setup_ai_agent()
	_setup_radius_collision()
	_setup_blackboard()
	
	emit_signal("respawn", self)
	set_physics_process(true)


func _on_BehaviorAnimPlayer_animation_started(anim_name: String) -> void:
	set_team(team)


func _on_HitArea_area_entered(area: Area2D) -> void:
	var target_lock = false
	if area.target == self and not target_lock:
		target_lock = true

		var damage = 0
		match attributes.primary.unit_type:
			Units.TypeID.Creep:
				damage = area.creep_damage
			Units.TypeID.Leader:
				damage = area.leader_damage
			Units.TypeID.Building:
				damage = area.building_damage
		
#		stats.change([
#			{name = "stats_health", value = stats.stats_health - damage}
#		])


func _on_Stats_changed(_properties: Array) -> void:
	$Blackboard.set_data("stats_health", attributes.stats.health)
	$Blackboard.set_data("stats_mana", attributes.stats.mana)
	$Blackboard.set_data("is_dead", attributes.stats.health <= 0)
#	_setup_healthbar()
