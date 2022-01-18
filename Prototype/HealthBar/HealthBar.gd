tool
extends Control

export(int) var stats_health: int = 0 setget set_stats_health
export(int) var stats_max_health: int = 0 setget set_stats_max_health

export(int) var stats_mana: int = 0 setget set_stats_mana
export(int) var stats_max_mana: int = 0 setget set_stats_max_mana

var _is_ready: bool = false

onready var healthbar: TextureProgress = $Health
onready var manahbar: TextureProgress = $Mana


func set_stats_health(value: int) -> void:
	stats_health = value
	
	if _is_ready:
		$Health.value = stats_health


func set_stats_max_health(value: int) -> void:
	stats_max_health = value
	
	if _is_ready:
		$Health.max_value = stats_max_health


func set_stats_mana(value: int) -> void:
	stats_mana = value
	
	if _is_ready:
		$Mana.value = stats_mana


func set_stats_max_mana(value: int) -> void:
	stats_max_mana = value
	
	if _is_ready:
		$Mana.max_value = stats_max_mana


func _ready() -> void:
	_is_ready = true
	set_stats_health(stats_health)
	set_stats_max_health(stats_max_health)
	set_stats_mana(stats_mana)
	set_stats_mana(stats_max_mana)
