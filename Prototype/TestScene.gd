extends Node2D

onready var leaders = {
	"maori": preload("res://Character/Child/Leader/Maori/Maori.tscn"),
	"daniel": preload("res://Character/Child/Leader/DEBUG_Daniel/Daniel.tscn"),
	"raja": preload("res://Character/Child/Leader/Raja/Raja.tscn")
}

func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")
	#auto preload all leaders
	#var bts = $Menu/LeaderSelection.group.get_buttons()
	#for bt in bts:
	#	preload("res://Character/Child/Leader/"+key+"/"+key+".tscn")
	
func _process(delta: float) -> void:
	$Menu/FPS.set_text((str(Engine.get_frames_per_second())))


func _on_Game_playing() -> void:
	if not Game.is_playing:
		var current_leader = $Menu/LeaderSelection.curent_leader
		var team = Player.selected_team
		Units.call_deferred("try_spawn_creep_wave", $BattleField)
		Units.call_deferred(
			"spawn_one",
			team,
			leaders[current_leader], 
			$BattleField, 
			$BattleField/Mid.points[1])
		$CreepRespawnTimer.start(Game.creep_respawn_time)
		Game.is_playing = true


func _on_CreepRespawnTimer_timeout() -> void:
	Units.call_deferred("try_spawn_creep_wave", $BattleField)
	#print("Spawn Creep")
