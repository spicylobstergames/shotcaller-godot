extends Node

signal switch_team

var selected_team: int = Units.TeamID.Blue setget set_selected_team



func set_selected_team(value: int) -> void:
	if selected_team != value:
		emit_signal("switch_team")
	selected_team = value
