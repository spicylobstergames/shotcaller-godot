extends StaticBody2D


export(Units.TeamID) var team = Units.TeamID.Blue setget set_team
export(Texture) var blue_team_texture: Texture
export(Texture) var red_team_texture: Texture

var _is_ready: bool = false
var is_dead: bool = false

var ai_accel: GSAITargetAcceleration = GSAITargetAcceleration.new()
var ai_agent: GSAISteeringAgent = GSAISteeringAgent.new()
var ai_target_location: GSAIAgentLocation

onready var stats: Node = $Stats
onready var sprite: Sprite = $TextureContainer/Sprite

onready var healthbar: Control = $HUD/HealthBar
onready var behavior_animplayer: AnimationPlayer = $BehaviorAnimPlayer
onready var blackbaord: Blackboard = $Blackboard
onready var behavior_tree: BehaviorTree = $BehaviorTree


func set_team(value: int) -> void:
	team = value
	if _is_ready:
		_setup_team()


func _ready() -> void:
	_is_ready = true
	_setup_ai_agent()
	_setup_blackboard()


func _physics_process(_delta: float) -> void:
	if stats.stats_health <= 0:
		_setup_dead()
	else:
		var enemies = Units.get_enemies(
				self,
				team,
				Units.TypeID.Creep,
				[Units.TypeID.Creep, Units.TypeID.Leader, Units.TypeID.Building],
				Units.DetectionTypeID.Area,
				stats.area_unit_detection
				)
		$Blackboard.set_data("enemies", enemies)
		
		var allies = Units.get_allies(
				self,
				team,
				Units.TypeID.Creep,
				[Units.TypeID.Creep, Units.TypeID.Leader, Units.TypeID.Building],
				Units.DetectionTypeID.Area,
				stats.area_unit_detection
				)
		$Blackboard.set_data("allies", allies)


func _setup_team() -> void:
	stats.team = team
	if blue_team_texture != null and red_team_texture != null:
		match team:
			Units.TeamID.Blue:
				sprite.texture = blue_team_texture
			Units.TeamID.Red:
				sprite.texture = red_team_texture


func _setup_healthbar() -> void:
	healthbar.stats_max_health = stats.stats_max_health
	healthbar.stats_health = stats.stats_health
	healthbar.stats_max_mana = stats.stats_max_mana
	healthbar.stats_mana = stats.stats_mana


func _setup_ai_agent() -> void:
	ai_agent.bounding_radius = stats.area_unit
	ai_agent.position = GSAIUtils.to_vector3(global_position)


func _setup_radius_collision() -> void:
	$CollisionShape2D.shape.radius = stats.area_unit
	$UnitSelector/CollisionShape2D.shape.radius = stats.area_selection
	$UnitDetector/CollisionShape2D.shape.radius = stats.area_unit_detection


func _setup_blackboard() -> void:
	$Blackboard.set_data("is_dead", false)
	$Blackboard.set_data("stats_health", stats.stats_health)
	$Blackboard.set_data("enemies", [])
	$Blackboard.set_data("allies", [])
	$Blackboard.set_data("targeted_enemy", null)


func _setup_dead() -> void:
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	$HitArea.collision_mask = 0
	$UnitDetector.collision_mask = 0
	$UnitSelector.collision_layer = 0
	behavior_tree.is_active = false
	blackbaord.set_data("is_dead", is_dead)
	set_physics_process(false)
	emit_signal("dead", self)

	if behavior_animplayer.has_animation("Dead") and behavior_animplayer.current_animation != "Dead":
		behavior_animplayer.play("Dead")

	yield(behavior_animplayer, "animation_finished")
	position.y = global_position.y - 1000


func _setup_spawn() -> void:
	behavior_tree.is_active = true
	pass


func _on_HitArea_area_entered(area: Area2D) -> void:
	var target_lock = false
	if area.target == self and not target_lock:
		target_lock = true

		var damage = 0
		match stats.unit_type:
			Units.TypeID.Creep:
				damage = area.creep_damage
			Units.TypeID.Leader:
				damage = area.leader_damage
			Units.TypeID.Building:
				damage = area.building_damage
		
		stats.change([
			{name = "stats_health", value = stats.stats_health - damage}
		])


func _on_Stats_changed(properties) -> void:
	$Blackboard.set_data("stats_health", stats.stats_health)
	$Blackboard.set_data("stats_mana", stats.stats_mana)
	$Blackboard.set_data("is_dead", stats.stats_health <= 0)
	_setup_healthbar()
