extends Projectile

var spear_stuck_scene = preload("res://Character/Child/Leader/Sami/Weapon/SpearStuck.tscn")

func on_impact(enemy):
	var new_stuck_spear = spear_stuck_scene.instance()
	if enemy.has_node("TextureContainer/AnimatedSprite"):
		enemy.get_node("TextureContainer/AnimatedSprite").add_child(new_stuck_spear)
	elif enemy.has_node("TextureContainer/Sprite"):
		enemy.get_node("TextureContainer/Sprite").add_child(new_stuck_spear)
	#new_stuck_spear.global_rotation = global_rotation
	new_stuck_spear.global_position = global_position
	#new_stuck_spear.rotate(rand_range(-0.2,0.2))
	new_stuck_spear.global_position += Vector2(rand_range(5.0,10.0),0.0).rotated(global_rotation)
	
	if (enemy.team == Units.TeamID.Blue or enemy.get_node("TextureContainer").scale.x == -1):
		new_stuck_spear.scale.x *= -1
