extends Node2D

onready var Leader_Group_Class = preload("res://Character/Child/Leader/LeaderGroup.tscn")

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
		var team = Player.selected_team
		
		var leader = $Menu/LeaderSelection.curent_leader.instance()
		var leader_group = Leader_Group_Class.instance()
		leader_group.add_child(leader);
		
		$Menu/HBoxContainer.hide()
		
		$Menu/LeadersInventories.add_inventory(leader)
		$Menu/Shop.add_delivery(leader)
		
		Units.selected_leader = leader
		
		Units.call_deferred("try_spawn_creep_wave", $BattleField)
		Units.call_deferred(
			"spawn_one",
			team,
			leader_group,
			$BattleField, 
			$BattleField/Mid.points[2])
		$CreepRespawnTimer.start(Game.creep_respawn_time)
		Game.is_playing = true


func _on_CreepRespawnTimer_timeout() -> void:
	Units.call_deferred("try_spawn_creep_wave", $BattleField)
	#print("Spawn Creep")
