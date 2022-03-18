extends Node2D

onready var Leader_Group_Class = preload("res://Character/Child/Leader/LeaderGroup.tscn")

func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")


func _process(delta: float) -> void:
	$Menu/FPS.set_text((str(Engine.get_frames_per_second())))


func _on_Game_playing() -> void:
	if not Game.is_playing:
		
		$Menu/HBoxContainer.hide()
		
		Units.call_deferred("try_spawn_creep_wave", $BattleField)
		$CreepRespawnTimer.start(Game.creep_respawn_time)
		
		_spawn_leaders()
		
		Game.is_playing = true


func _on_CreepRespawnTimer_timeout() -> void:
	Units.call_deferred("try_spawn_creep_wave", $BattleField)
	#print("Spawn Creep")


onready var top_blue = $BattleField/Top.points[2]
onready var mid_blue = $BattleField/Mid.points[2]
onready var bot_blue = $BattleField/Bot.points[2]

onready var top_red = $BattleField/Top.points[4]
onready var mid_red = $BattleField/Mid.points[4]
onready var bot_red = $BattleField/Bot.points[4]

onready var spawn_points = [
	[], # Neutrals
	[top_blue, top_blue, mid_blue, bot_blue, bot_blue],
	[bot_red, bot_red, mid_red, top_red, top_red]
]

func _spawn_leaders() -> void:
	var last_leader
	var i = 0
	for bt in $Menu/ChooseLeader.leader_group.get_buttons():
		for team in [Units.TeamID.Blue, Units.TeamID.Red]:
			#var team = Player.selected_team
			var leader = $Menu/ChooseLeader[bt.name].instance()
			var leader_group = Leader_Group_Class.instance()
			leader_group.add_child(leader)
			var spawn_point = spawn_points[team-1][i]
			#randomize()
			spawn_point.x += randf() - 0.5
			spawn_point.y += randf() - 0.5
			Units.call_deferred("spawn_one", team, leader_group, $BattleField, spawn_point)
			last_leader = leader
		i += 1
	
	$Menu/LeadersInventories.add_inventory(last_leader)
	$Menu/Shop.add_delivery(last_leader)
