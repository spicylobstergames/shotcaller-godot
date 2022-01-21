tool
extends Control

export(int) var health: int = 0 setget set_health
export(int) var max_health: int = 0 setget set_max_health

export(int) var mana: int = 0 setget set_mana
export(int) var max_mana: int = 0 setget set_max_mana

var _is_ready: bool = false

onready var healthbar: TextureProgress = $Health
onready var manahbar: TextureProgress = $Mana


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


func _ready() -> void:
	_is_ready = true
	set_health(health)
	set_max_health(max_health)
	set_mana(mana)
	set_mana(max_mana)
