extends StaticBody2D


export(Units.TeamID) var team = Units.TeamID.Blue setget set_team
export(Texture) var blue_team_texture: Texture
export(Texture) var red_team_texture: Texture

var _is_ready: bool = false
var is_dead: bool = false

var ai_accel: GSAITargetAcceleration = GSAITargetAcceleration.new()
var ai_agent: GSAISteeringAgent = GSAISteeringAgent.new()

var targeted_enemy

onready var attributes: Node = $Attributes
onready var sprite: Sprite = $TextureContainer/Sprite

onready var healthbar: Control = $HUD/HealthBar
onready var behavior_animplayer: AnimationPlayer = $BehaviorAnimPlayer
onready var behavior_tree: BehaviorTree = $BehaviorTree

var enemies = []
var allies = []


func set_team(value: int) -> void:
	team = value
	if _is_ready:
		_setup_team()


func _ready() -> void:
	_is_ready = true
	
	is_dead = false
	enemies = []
	allies = []
	targeted_enemy = null

	_setup_ai_agent()
	_setup_healthbar()


func _physics_process(_delta: float) -> void:
	if attributes.stats.health <= 0:
		_setup_dead()
	_setup_healthbar()
	enemies = Units.get_enemies(
			self,
			team,
			Units.TypeID.Creep,
			[Units.TypeID.Creep, Units.TypeID.Leader, Units.TypeID.Building],
			Units.DetectionTypeID.Area,
			attributes.radius.unit_detection
			)

	
	allies = Units.get_allies(
			self,
			team,
			Units.TypeID.Creep,
			[Units.TypeID.Creep, Units.TypeID.Leader, Units.TypeID.Building],
			Units.DetectionTypeID.Area,
			attributes.radius.unit_detection
			)




func _setup_team() -> void:
	attributes.primary.unit_team = team
	if blue_team_texture != null and red_team_texture != null:
		match team:
			Units.TeamID.Blue:
				sprite.texture = blue_team_texture
			Units.TeamID.Red:
				sprite.texture = red_team_texture


func _setup_healthbar() -> void:
	healthbar.set_team(attributes.primary.unit_team)
	healthbar.set_max_health(attributes.stats.max_health)
	healthbar.set_health(attributes.stats.health)
	healthbar.set_max_mana(attributes.stats.max_mana)
	healthbar.set_mana(attributes.stats.mana)


func _setup_ai_agent() -> void:
	ai_agent.bounding_radius = attributes.radius.collision_size
	ai_agent.position = GSAIUtils.to_vector3(global_position)


func _setup_radius_collision() -> void:
	$CollisionShape2D.shape.radius = attributes.radius.collision_size
	$UnitSelector/CollisionShape2D.shape.radius = attributes.radius.area_selection
	$UnitDetector/CollisionShape2D.shape.radius = attributes.radius.unit_detection


func _setup_dead() -> void:
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	$HitArea.collision_mask = 0
	$UnitDetector.collision_mask = 0
	$UnitSelector.collision_layer = 0
	behavior_tree.is_active = false
	set_physics_process(false)
	#emit_signal("dead", self)

	if behavior_animplayer.has_animation("Dead") and behavior_animplayer.current_animation != "Dead":
		behavior_animplayer.play("Dead")

	yield(behavior_animplayer, "animation_finished")
	final_actions()
	queue_free()
#	position.y = global_position.y - 1000

func final_actions():
	pass

func _setup_spawn() -> void:
	behavior_tree.is_active = true
	pass

func _on_attributes_stats_changed(prop_name, prop_value) -> void:
	match prop_name:
		"health", "mana", "max_health", "max_mana":
			_setup_healthbar()
