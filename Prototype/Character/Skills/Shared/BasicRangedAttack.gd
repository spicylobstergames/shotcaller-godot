extends Skill

export var projectile_range: float
export var speed: float
onready var lifetime = projectile_range/speed

export var projectile_scene: PackedScene
export(int) var creep_damage: int = 0
export(int) var leader_damage: int = 0
export(int) var building_damage: int = 0
export var spawn_position_node: NodePath

func cast():
	var super_result = .cast()
	if super_result:
		var battlefield = get_tree().get_nodes_in_group("battlefield")[0]
		var new_projectile = projectile_scene.instance()

		if is_instance_valid(get_node(spawn_position_node)):
			new_projectile.global_position = get_node(spawn_position_node).global_position
		else:
			new_projectile.global_position = agent.global_position
		new_projectile.rotation = agent.get_node("AimPoint").global_position.angle_to_point(new_projectile.global_position)
		new_projectile.team = agent.attributes.primary.unit_team
		new_projectile.creep_damage = creep_damage
		new_projectile.leader_damage = leader_damage
		new_projectile.building_damage = building_damage
		new_projectile.velocity = speed
		new_projectile.lifetime = lifetime
		battlefield.add_child(new_projectile)
	return super_result

func get_range():
	return projectile_range
