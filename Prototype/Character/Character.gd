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

var leader: Node = null
var formation_target: Vector2 = Vector2(0.0, 0.0)

var targeted_location: Vector2 = Vector2.ZERO
var targeted_enemy: PhysicsBody2D = null
var targeted_ally: PhysicsBody2D = null

var detected_units: Dictionary = {}


var ai_accel: GSAITargetAcceleration = GSAITargetAcceleration.new()
var ai_agent: GSAIKinematicBody2DAgent = GSAIKinematicBody2DAgent.new(self, GSAIKinematicBody2DAgent.MovementType.COLLIDE)

var shape = Physics2DShapeQueryParameters.new()
var circle_shape = CircleShape2D.new()

var allies = []
var enemies = []
var buildings = []
var target_end_point

onready var space_state = get_world_2d().direct_space_state


onready var attributes: Node = $Attributes
onready var sprite: Sprite = $TextureContainer/Sprite
onready var smoke: AnimatedSprite = $TextureContainer/Smoke
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
	
	is_dead = false
	targeted_enemy = null
	target_end_point = global_position
	$AimPoint.visible = ProjectSettings.get("global/debug")
	set_physics_process(false)
	set_team(team)
	_setup_spawn()
	# if animation == running
	set_smoke()

var resize_smoke = true;
func set_smoke() -> void:
	var size = 10
	var count: int = smoke.frames.get_frame_count('default')
	if (resize_smoke):
		resize_smoke = false;
		for n in count:
			var texture: Texture = smoke.get_sprite_frames().get_frame('default', n);
			if (texture):
				var image: Image = texture.get_data()
				image.resize(size, size, Image.INTERPOLATE_NEAREST)
				var texture2 = ImageTexture.new()
				texture2.create_from_image(image, 0)
				smoke.get_sprite_frames().set_frame('default', n, texture2)
	# finish resize_smoke
	randomize()
	var offset: int = rand_range(0, count );
	smoke.set_frame(offset)
	smoke.play('default')

func _physics_process(delta: float) -> void:
	
	ai_agent._apply_steering(ai_accel, delta)
	ai_accel.set_zero()
	velocity = GSAIUtils.to_vector2(ai_agent.linear_velocity)
	if velocity.length() > 10.0:
		if behavior_animplayer.has_animation("Walk") and behavior_animplayer.current_animation != "Walk" :
			behavior_animplayer.play("Walk")
	if attributes.stats.health <= 0:
		_setup_dead()
	else:
		enemies = Units.get_enemies(
				self,
				team,
				attributes.primary.unit_type,
				[Units.TypeID.Creep, Units.TypeID.Leader, Units.TypeID.Building],
				Units.DetectionTypeID.Area,
				attributes.radius.unit_detection
				)
		
		allies = Units.get_allies(
				self,
				team,
				attributes.primary.unit_type,
				[Units.TypeID.Creep, Units.TypeID.Leader, Units.TypeID.Building],
				Units.DetectionTypeID.Area,
				attributes.radius.unit_detection
				)
	if is_instance_valid(targeted_enemy):
		$AimPoint.visible = true
		$AimPoint.global_position = targeted_enemy.get_node("HitArea").global_position
	else:
		$AimPoint.visible = false
func _draw() -> void:
	
	if ProjectSettings.get("global/debug"):
		Utils.draw_line_circle(self, attributes.radius.attack_range, 1.0, Color(0,0,1,0.5))
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
	ai_agent.linear_drag_percentage = 0.1
	ai_agent.apply_linear_drag = true
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


func _setup_dead() -> void:
	set_physics_process(false)
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	$HitArea.collision_mask = 0
	$UnitDetector.collision_mask = 0
	$UnitSelector.collision_layer = 0
	$BehaviorTree.is_active = false
	emit_signal("dead", self)

	if behavior_animplayer.has_animation("Dead") and behavior_animplayer.current_animation != "Dead":
		behavior_animplayer.play("Dead")

	yield(behavior_animplayer, "animation_finished")
	queue_free()
#	position.y = global_position.y - 1000


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
	
	for p in attributes.stats._saved_init_properties.keys():
		attributes.stats.set(p, attributes.stats._saved_init_properties[p])
	
	set_team(team)
	_setup_healthbar()
	_setup_ai_agent()
	_setup_radius_collision()
	
	emit_signal("respawn", self)
	set_physics_process(true)


func _on_BehaviorAnimPlayer_animation_started(anim_name: String) -> void:
	set_team(team)


func _on_attributes_stats_changed(prop_name, prop_value) -> void:
	match prop_name:
		"health", "mana", "max_health", "max_mana":
			_setup_healthbar()

