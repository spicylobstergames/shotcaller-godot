extends Node2D

onready var leader_scene = preload("res://Character/Child/Leader/DEBUG_Daniel/Daniel.tscn")

func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")
	
	
func _process(delta: float) -> void:
	$Menu/FPS.set_text((str(Engine.get_frames_per_second())))


func _on_Game_playing() -> void:
	if not Game.is_playing:
		var team = Player.selected_team
		Units.call_deferred("try_spawn_creep_wave", $BattleField)
		Units.call_deferred(
			"spawn_one",
			team,
			leader_scene, 
			$BattleField, 
			Units.arena_teams[team].mid_creep_spawner_position + Vector2(rand_range(-100.0, 100.0), rand_range(-100.0, 100.0)))
		$CreepRespawnTimer.start(Game.creep_respawn_time)
		Game.is_playing = true


func _on_CreepRespawnTimer_timeout() -> void:
	Units.call_deferred("try_spawn_creep_wave", $BattleField)
	#print("Spawn Creep")
