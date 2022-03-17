extends "res://Character/Child/Leader/Leader.gd"

func _setup_ats() -> void:
	$BehaviorAnimPlayer.playback_speed = $Attributes.stats.attack_speed/100
	

func _reset_ats() -> void:
	$BehaviorAnimPlayer.playback_speed = 1
