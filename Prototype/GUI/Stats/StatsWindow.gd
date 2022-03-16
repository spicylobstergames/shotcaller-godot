extends Node2D


# Called when the node enters the scene tree for the first time.
#func _ready():
#	pass # Replace with function body.


func update_window(unit):
	if unit:
		var dmg = unit.get_node("Attributes").stats.leader_damage
		get_node("DamageValue").text = str(dmg)
	else: get_node("DamageValue").text = "0"
