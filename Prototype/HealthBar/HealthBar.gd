tool
extends Control

export(Units.TeamID) var team = Units.TeamID.Blue setget set_team

export(int) var health: int = 0 setget set_health
export(int) var max_health: int = 0 setget set_max_health

export(int) var mana: int = 0 setget set_mana
export(int) var max_mana: int = 0 setget set_max_mana

var _is_ready: bool = false

onready var healthbar: TextureProgress = $Health
onready var manahbar: TextureProgress = $Mana

var green: Color = Color(0.05, 0.68, 0.12, 1)
var red: Color = Color(1, 0.35, 0.26, 1)

func set_health(value: int) -> void:
	health = value
	
	if _is_ready:
		$Health.value = health


func set_max_health(value: int) -> void:
	max_health = value
	
	if _is_ready:
		$Health.max_value = max_health if value != 0 else 1


func set_mana(value: int) -> void:
	mana = value
	
	if _is_ready:
		$Mana.value = mana


func set_max_mana(value: int) -> void:
	max_mana = value
	
	if _is_ready:
		$Mana.max_value = max_mana if value != 0 else 1

func set_team(value: int) -> void:
	team = value
	if _is_ready:
		_setup_team()
		
func _setup_team() -> void:
	match team:
		Units.TeamID.Blue:
			$Health.tint_progress = green
		Units.TeamID.Red:
			$Health.tint_progress = red


func _ready() -> void:
	_is_ready = true
	set_health(health)
	set_max_health(max_health)
	set_mana(mana)
	set_mana(max_mana)
