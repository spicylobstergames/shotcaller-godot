extends "res://Character/Child/Creep/Creep.gd"


export(PackedScene) var _arrow: PackedScene = null


func _physics_process(delta: float) -> void:
	var target = $Blackboard.get_data("targeted_enemy")
	if target:
		$TextureContainer/Position2D.look_at(target.global_position)


func _setup_team() -> void:
	match team:
		Units.TeamID.Blue:
			$TextureContainer/AnimatedSprite.frame = 0
			$TextureContainer/Position2D/Weapon.frame = 0
		Units.TeamID.Red:
			$TextureContainer/AnimatedSprite.frame = 1
			$TextureContainer/Position2D/Weapon.frame = 1
	._setup_team()


func _setup_basic_attack() -> void:
	var target = $Blackboard.get_data("targeted_enemy")

	if target and not target.is_dead:
		var arrow: Area2D = _arrow.instance()
		arrow.position = Vector2.ZERO
		
		arrow.creep_damage = stats.stats_creep_damage
		arrow.leader_damage = stats.stats_leader_damage
		arrow.building_damage = stats.stats_building_damage
		arrow.target = target
		
		$TextureContainer/Position2D/Weapon/ArrowInitPosition.add_child(arrow)
		arrow.release()
