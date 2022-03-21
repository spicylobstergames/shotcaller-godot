extends Node2D

func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")


func _process(delta: float) -> void:
	$Menu/FPS.set_text((str(Engine.get_frames_per_second())))


func _on_Game_playing() -> void:
	if not Game.is_playing:
		
		$Menu/HBoxContainer.hide()
		
		Units.call_deferred("try_spawn_creep_wave", $BattleField)
		$CreepRespawnTimer.start(Game.creep_respawn_time)
		
		Leaders.call_deferred("spawn_leaders", self)
		
		Game.is_playing = true


func _on_CreepRespawnTimer_timeout() -> void:
	Units.call_deferred("try_spawn_creep_wave", $BattleField)
	#print("Spawn Creep")

