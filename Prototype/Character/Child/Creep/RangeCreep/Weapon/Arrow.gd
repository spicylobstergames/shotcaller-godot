extends Projectile

var arrow_stuck_scene = preload("res://Character/Child/Creep/RangeCreep/Weapon/ArrowStuck.tscn")

func on_impact(enemy):
	var new_stuck_arrow = arrow_stuck_scene.instance()
	if enemy.has_node("TextureContainer/AnimatedSprite"):
		enemy.get_node("TextureContainer/AnimatedSprite").add_child(new_stuck_arrow)
	elif enemy.has_node("TextureContainer/Sprite"):
		enemy.get_node("TextureContainer/Sprite").add_child(new_stuck_arrow)
	new_stuck_arrow.global_rotation = global_rotation
	new_stuck_arrow.global_position = global_position
	new_stuck_arrow.rotate(rand_range(-0.2,0.2))
	new_stuck_arrow.global_position += Vector2(rand_range(5.0,10.0),0.0).rotated(global_rotation)
