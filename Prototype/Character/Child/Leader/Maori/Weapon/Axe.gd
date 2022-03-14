extends Projectile

var axe_stuck_scene = preload("res://Character/Child/Leader/Maori/Weapon/AxeStuck.tscn")

func on_impact(enemy):
	var new_stuck_axe = axe_stuck_scene.instance()
	if enemy.has_node("TextureContainer/AnimatedSprite"):
		enemy.get_node("TextureContainer/AnimatedSprite").add_child(new_stuck_axe)
	elif enemy.has_node("TextureContainer/Sprite"):
		enemy.get_node("TextureContainer/Sprite").add_child(new_stuck_axe)
	new_stuck_axe.global_rotation = global_rotation
	new_stuck_axe.global_position = global_position
	new_stuck_axe.rotate(rand_range(-0.1,0.1))
	new_stuck_axe.global_position += Vector2(rand_range(6.0,12.0),0.0).rotated(global_rotation)
	# I have no idea why the axe y scale is being flipped on those cases
	# but this fixes it
	if (enemy.team == Units.TeamID.Blue or enemy.get_node("TextureContainer").scale.x == -1):
		new_stuck_axe.scale.y *= -1
	
