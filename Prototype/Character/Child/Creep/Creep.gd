extends "res://Character/Character.gd"



func _ready():
	$Node/Line2D.visible = ProjectSettings.get("global/debug")
	
