extends Node2D


func update_window(unit):
	if unit:
		show()
		var dmg = unit.get_node("Attributes").stats.damage
		get_node("DamageValue").text = str(dmg)
		var ats = unit.get_node("Attributes").stats.attack_speed
		get_node("AttackSpeedValue").text = str(ats)
		var spd = unit.get_node("Attributes").stats.move_speed
		get_node("MoveSpeedValue").text = str(spd)
		var rng = unit.get_node("Attributes").radius.attack_range
		get_node("RangeValue").text = str(rng)
		if unit.has_node("TextureContainer/AnimatedSprite"):
			get_node("Portrait/Sprite").hide()
			var frames = unit.get_node("TextureContainer/AnimatedSprite").frames
			get_node("Portrait/AnimatedSprite").frames = frames
			var frame = unit.get_node("TextureContainer/AnimatedSprite").frame
			get_node("Portrait/AnimatedSprite").frame = frame
			get_node("Portrait/AnimatedSprite").show()
		else:
			get_node("Portrait/AnimatedSprite").hide()
			var texture = unit.get_node("TextureContainer/Sprite").texture
			get_node("Portrait/Sprite").texture = texture
			var region_rect = unit.get_node("TextureContainer/Sprite").region_rect
			get_node("Portrait/Sprite").region_rect = region_rect
			get_node("Portrait/Sprite").show()
		if unit.team == Units.TeamID.Red and get_node("Portrait/AnimatedSprite").scale.x > 1:
			get_node("Portrait/AnimatedSprite").scale.x *= -1
		if unit.team == Units.TeamID.Blue and get_node("Portrait/AnimatedSprite").scale.x < 1:
			get_node("Portrait/AnimatedSprite").scale.x *= -1
	else:
		hide()
		get_node("DamageValue").text = "0"
		get_node("AttackSpeedValue").text = "0"
		get_node("MoveSpeedValue").text = "0"
		get_node("RangeValue").text = "0"
