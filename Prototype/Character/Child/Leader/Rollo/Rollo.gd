extends "res://Character/Child/Leader/Leader.gd"

func _setup_team() -> void:
	match team:
		Units.TeamID.Blue:
			$TextureContainer/AnimatedSprite.frame = 0
			$TextureContainer/Weapon.frame = 0
		Units.TeamID.Red:
			$TextureContainer/AnimatedSprite.frame = 1
			$TextureContainer/Weapon.frame = 1
	._setup_team()


func _setup_ats() -> void:
	$BehaviorAnimPlayer.playback_speed = $Attributes.stats.attack_speed/100


func _reset_ats() -> void:
	$BehaviorAnimPlayer.playback_speed = 1
