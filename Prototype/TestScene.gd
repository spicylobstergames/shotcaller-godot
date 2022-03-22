extends Node2D

var _game_start:bool = true

var _stats_state:bool


func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")


func _process(delta: float) -> void:
	$GUI/FPS.set_text((str(Engine.get_frames_per_second())))


func _on_Game_playing() -> void:
	if not Game.is_playing:
		
		_show_GUI()
		_hide_Menu()
		
		if _game_start:
		
			#Units.call_deferred("try_spawn_creep_wave", $BattleField)
			#$CreepRespawnTimer.start(Game.creep_respawn_time)
			
			Leaders.call_deferred("spawn_leaders", self)
			
			_game_start = false
		
		Game.is_playing = true
		get_tree().paused = false



func _on_CreepRespawnTimer_timeout() -> void:
	Units.call_deferred("try_spawn_creep_wave", $BattleField)
	#print("Spawn Creep")


func _on_MenuButton_pressed():
	_hide_GUI()
	$Menu/Label.text = 'PAUSE'
	_show_Menu()
	Game.is_playing = false
	get_tree().paused = true


func _hide_GUI():
	$GUI/FPS.hide()
	_stats_state = $GUI/StatsWindow.visible
	$GUI/StatsWindow.hide()
	$GUI/Minimap.hide()
	$GUI/Shop.hide()
	$GUI/MenuButton.hide()

func _show_GUI():
	$GUI/FPS.show()
	$GUI/StatsWindow.visible = _stats_state
	$GUI/Minimap.show()
	$GUI/Shop.show()
	$GUI/MenuButton.show()



func _hide_Menu():
	$Menu/HBoxContainer.hide()
	$Menu/Label.hide()
	
func _show_Menu():
	$Menu/HBoxContainer.show()
	$Menu/Label.show()
	
