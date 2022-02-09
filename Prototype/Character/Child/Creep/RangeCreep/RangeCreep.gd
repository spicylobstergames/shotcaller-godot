extends "res://Character/Child/Creep/Creep.gd"

func _physics_process(delta: float) -> void:
	if is_instance_valid(targeted_enemy):
		$TextureContainer/Position2D.look_at(targeted_enemy.global_position)


func _setup_team() -> void:
	match team:
		Units.TeamID.Blue:
			$TextureContainer/AnimatedSprite.frame = 0
			$TextureContainer/Position2D/Weapon.frame = 0
		Units.TeamID.Red:
			$TextureContainer/AnimatedSprite.frame = 1
			$TextureContainer/Position2D/Weapon.frame = 1
	._setup_team()
