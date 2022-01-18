extends Position2D

export(Units.TeamID) var team = Units.TeamID.Blue setget set_team


var _is_ready: bool = false

func set_team(value: int) -> void:
	team = value
	if _is_ready:
		setup_team()

func _ready() -> void:
	_is_ready = true


func setup_team() -> void:
	pass
