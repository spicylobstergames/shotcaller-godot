extends Node2D

var team: int
var velocity = Vector2(0.0,0.0)
var speed_increase

var blue_colors =  [Color("#342d71"), Color("#2d55ff"), Color("#00b5cc")]
var red_colors =  [Color.red, Color.brown, Color.crimson]

func _ready():
	rotation = -PI/2.0 + rand_range(-0.5, 0.5)
	$AnimationPlayer.playback_speed = rand_range(0.9, 1.1)
	speed_increase = rand_range(0.9, 5.0)
	velocity = Vector2(rand_range(1.0, 5.0), 0.0).rotated(rotation)
	match team:
		Units.TeamID.Blue:
			$ExplosionParticles.modulate = blue_colors[randi() % blue_colors.size()]
		Units.TeamID.Red:
			$ExplosionParticles.modulate = red_colors[randi() % red_colors.size()]


func _physics_process(delta):
	if $TrailParticles.emitting:
		velocity += Vector2(speed_increase * delta, 0.0).rotated(rotation)
	velocity.y += 0.5 * delta
	rotation = velocity.angle()
	position += velocity

func leave_explosion_behind():
	var explosion = $ExplosionParticles
	var old_position = explosion.global_position
	remove_child(explosion)
	get_parent().add_child(explosion)
	explosion.global_position = old_position
	explosion.emitting = true
