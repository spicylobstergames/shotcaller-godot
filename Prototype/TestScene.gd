extends Node2D



func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")
	
	
func _process(delta: float) -> void:
	$Menu/FPS.set_text((str(Engine.get_frames_per_second())))
	

func _on_Game_playing() -> void:
	if not Game.is_playing:
		Units.call_deferred("spawn_creep", $BattleField)
		$CreepRespawnTimer.start(Game.creep_respawn_time)
		Game.is_playing = true
		print("First Spawn Creep")


func _on_CreepRespawnTimer_timeout() -> void:
	Units.call_deferred("spawn_creep", $BattleField)
	print("Spawn Creep")
