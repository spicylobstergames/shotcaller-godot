class_name Projectile
extends Area2D

var velocity: float
var lifetime: float
var creep_damage: int = 0
var leader_damage: int = 0
var building_damage: int = 0

var team = Units.TeamID.Neutral

func _ready():
	connect("body_entered",self, "_on_body_entered")

func _process(delta):
	global_position += Vector2(velocity * delta, 0.0).rotated(rotation)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body):
	if visible and team != body.attributes.primary.unit_team:
		var damage = 0
		match body.attributes.primary.unit_type:
			Units.TypeID.Creep:
				damage = creep_damage
			Units.TypeID.Leader:
				damage = leader_damage
			Units.TypeID.Building:
				damage = building_damage
		body.attributes.stats.emit_signal("change_property", "health", body.attributes.stats.health - damage, funcref(body, "_on_attributes_stats_changed"))
		visible = false
		queue_free()
