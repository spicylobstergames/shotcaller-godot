extends Node2D

onready var Leader_Group_Class = preload("res://Character/Child/Leader/LeaderGroup.tscn")

func _ready() -> void:
	Game.connect("playing", self, "_on_Game_playing")


func _process(delta: float) -> void:
	$Menu/FPS.set_text((str(Engine.get_frames_per_second())))


func _on_Game_playing() -> void:
	if not Game.is_playing:
		
		_spawn_leaders()
		
		$Menu/HBoxContainer.hide()
		#Units.selected_leader = leader[0]
		
		Units.call_deferred("try_spawn_creep_wave", $BattleField)
		$CreepRespawnTimer.start(Game.creep_respawn_time)
		Game.is_playing = true


func _on_CreepRespawnTimer_timeout() -> void:
	Units.call_deferred("try_spawn_creep_wave", $BattleField)
	#print("Spawn Creep")


onready var top = $BattleField/Top.points[3]
onready var mid = $BattleField/Mid.points[3]
onready var bot = $BattleField/Bot.points[3]


func _spawn_leaders() -> void:
	var p = 0
	var last_leader
	
	for l in $Menu/ChooseLeader.leaders:
		var timer = get_tree().create_timer(p)
		timer.connect("timeout", self, "_spawn_leader"+str(p)) 
		p += 1


func _spawn_leader0() -> void:
	var team = Player.selected_team
	var leader = $Menu/ChooseLeader.leaders["maori"].instance()
	var leader_group = Leader_Group_Class.instance()
	leader_group.add_child(leader);
	Units.call_deferred("spawn_one", team, leader_group, $BattleField, mid)
	$Menu/LeadersInventories.add_inventory(leader)
	$Menu/Shop.add_delivery(leader)


func _spawn_leader1() -> void:
	var team = Player.selected_team
	var leader = $Menu/ChooseLeader.leaders["raja"].instance()
	var leader_group = Leader_Group_Class.instance()
	leader_group.add_child(leader);
	Units.call_deferred("spawn_one", team, leader_group, $BattleField, top)

func _spawn_leader2() -> void:
	var team = Player.selected_team
	var leader = $Menu/ChooseLeader.leaders["robin"].instance()
	var leader_group = Leader_Group_Class.instance()
	leader_group.add_child(leader);
	Units.call_deferred("spawn_one", team, leader_group, $BattleField, top)

func _spawn_leader3() -> void:
	var team = Player.selected_team
	var leader = $Menu/ChooseLeader.leaders["rollo"].instance()
	var leader_group = Leader_Group_Class.instance()
	leader_group.add_child(leader);
	Units.call_deferred("spawn_one", team, leader_group, $BattleField, bot)

func _spawn_leader4() -> void:
	var team = Player.selected_team
	var leader = $Menu/ChooseLeader.leaders["sami"].instance()
	var leader_group = Leader_Group_Class.instance()
	leader_group.add_child(leader);
	Units.call_deferred("spawn_one", team, leader_group, $BattleField, bot)

