extends Projectile

var spear_stuck_scene = preload("res://Character/Child/Leader/Sami/Weapon/SpearStuck.tscn")

func on_impact(enemy):
	var new_stuck_spear = spear_stuck_scene.instance()
	var container = Node2D.new()
	container.add_child(new_stuck_spear)
	if enemy.has_node("TextureContainer/AnimatedSprite"):
		enemy.get_node("TextureContainer/AnimatedSprite").add_child(container)
	elif enemy.has_node("TextureContainer/Sprite"):
		enemy.get_node("TextureContainer/Sprite").add_child(container)
	container.global_rotation = global_rotation
	container.global_position = global_position
	container.rotate(rand_range(-0.1,0.1))
	container.global_position += Vector2(rand_range(7.0,10.0),0.0).rotated(global_rotation)
		
	if enemy.get_node("TextureContainer").scale.x == -1:
		container.global_rotation += 2*PI
