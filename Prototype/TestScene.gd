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
	var last_leader
	_spawn_leader0()
	_spawn_leader1()
	_spawn_leader2()
	_spawn_leader3()
	_spawn_leader4()
#	for p in 5:
#		var timer = get_tree().create_timer(p)
#		timer.connect("timeout", self, "_spawn_leader"+str(p)) 
#		p += 1

var leader_group0
var leader0
func _spawn_leader0() -> void:
	var team = Player.selected_team
	leader0 = $Menu/ChooseLeader.maori.instance()
	leader_group0 = Leader_Group_Class.instance()
	leader_group0.add_child(leader0);
	Units.call_deferred("spawn_one", team, leader_group0, $BattleField, mid)
	$Menu/LeadersInventories.add_inventory(leader0)
	$Menu/Shop.add_delivery(leader0)

var leader_group1
var leader1
func _spawn_leader1() -> void:
	var team = Player.selected_team
	leader1 = $Menu/ChooseLeader.raja.instance()
	leader_group1 = Leader_Group_Class.instance()
	leader_group1.add_child(leader1);
	Units.call_deferred("spawn_one", team, leader_group1, $BattleField, top)

var leader_group2
var leader2
func _spawn_leader2() -> void:
	var team = Player.selected_team
	leader2 = $Menu/ChooseLeader.robin.instance()
	leader_group2 = Leader_Group_Class.instance()
	leader_group2.add_child(leader2);
	Units.call_deferred("spawn_one", team, leader_group2, $BattleField, top)

var leader_group3
var leader3
func _spawn_leader3() -> void:
	var team = Player.selected_team
	leader3 = $Menu/ChooseLeader.rollo.instance()
	leader_group3 = Leader_Group_Class.instance()
	leader_group3.add_child(leader3);
	Units.call_deferred("spawn_one", team, leader_group3, $BattleField, bot)

var leader_group4
var leader4
func _spawn_leader4() -> void:
	var team = Player.selected_team
	leader4 = $Menu/ChooseLeader.sami.instance()
	leader_group4 = Leader_Group_Class.instance()
	leader_group4.add_child(leader4);
	Units.call_deferred("spawn_one", team, leader_group4, $BattleField, bot)

