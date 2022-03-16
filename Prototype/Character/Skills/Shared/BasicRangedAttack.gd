extends Skill

export var speed: float
onready var lifetime: float = get_range()/speed

export var projectile_scene: PackedScene
export onready var damage: int = get_damage()
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
		

		new_projectile.team = agent.attributes.primary.unit_team
		new_projectile.damage = damage
		new_projectile.velocity = speed
		new_projectile.lifetime = lifetime
		battlefield.add_child(new_projectile)
		new_projectile.rotation = agent.get_node("AimPoint").global_position.angle_to_point(new_projectile.global_position)
	return super_result

func get_damage():
	var skill = get_parent()
	var unit = skill.get_parent()
	var attributes = unit.get_node("Attributes")
	return attributes.stats.damage
	
func get_range():
	var skill = get_parent()
	var unit = skill.get_parent()
	var attributes = unit.get_node("Attributes")
	return attributes.radius.attack_range 

