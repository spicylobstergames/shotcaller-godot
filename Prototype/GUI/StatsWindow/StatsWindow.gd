extends Node2D


# Called when the node enters the scene tree for the first time.
#func _ready():
#	pass # Replace with function body.


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
	else:
		hide()
		get_node("DamageValue").text = "0"
		get_node("AttackSpeedValue").text = "0"
		get_node("MoveSpeedValue").text = "0"
		get_node("RangeValue").text = "0"
