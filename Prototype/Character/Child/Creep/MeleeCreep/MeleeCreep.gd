extends "res://Character/Child/Creep/Creep.gd"



#func _ready() -> void:
#	_setup_basic_attack()


func _setup_team() -> void:
	match team:
		Units.TeamID.Blue:
			$TextureContainer/AnimatedSprite.frame = 0
			$TextureContainer/Weapon.frame = 0
		Units.TeamID.Red:
			$TextureContainer/AnimatedSprite.frame = 1
			$TextureContainer/Weapon.frame = 1
	._setup_team()


func _setup_basic_attack() -> void:
	$TextureContainer/Weapon/BasicAttackArea.creep_damage = stats.stats_creep_damage
	$TextureContainer/Weapon/BasicAttackArea.leader_damage = stats.stats_leader_damage
	$TextureContainer/Weapon/BasicAttackArea.building_damage = stats.stats_building_damage
	$TextureContainer/Weapon/BasicAttackArea.target = $Blackboard.get_data("targeted_enemy")
