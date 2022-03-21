extends Node

signal leaders_spawned

enum LeadersID {Maori, Raja, Robin, Rollo, Sami}

var Leader_Group_Class:PackedScene = preload("res://Character/Child/Leader/LeaderGroup.tscn")

var maori:PackedScene = preload("res://Character/Child/Leader/Maori/Maori.tscn")
var raja:PackedScene =  preload("res://Character/Child/Leader/Raja/Raja.tscn")
var robin:PackedScene = preload("res://Character/Child/Leader/Robin/Robin.tscn")
var rollo:PackedScene = preload("res://Character/Child/Leader/Rollo/Rollo.tscn")
var sami:PackedScene =  preload("res://Character/Child/Leader/Sami/Sami.tscn")

var packed_leaders:Array = [maori, raja, robin, rollo, sami]
export var current_leaders:Array = []

func spawn_leaders(parent_node: Node2D) -> void:
	
	var top_blue:Vector2 = parent_node.get_node("BattleField/Top").points[2]
	var mid_blue:Vector2 = parent_node.get_node("BattleField/Mid").points[2]
	var bot_blue:Vector2 = parent_node.get_node("BattleField/Bot").points[2]

	var top_red:Vector2 = parent_node.get_node("BattleField/Top").points[4]
	var mid_red:Vector2 = parent_node.get_node("BattleField/Mid").points[4]
	var bot_red:Vector2 = parent_node.get_node("BattleField/Bot").points[4]

	var spawn_points:Array = Array(Units.TeamID.values())
	spawn_points[Units.TeamID.Blue] = [top_blue, top_blue, mid_blue, bot_blue, bot_blue]
	spawn_points[Units.TeamID.Red] = [bot_red, bot_red, mid_red, top_red, top_red]
	
	for team in [Units.TeamID.Blue, Units.TeamID.Red]:
		for i in range(5):
			#var team = Player.selected_team
			var leader = packed_leaders[i].instance()
			if team == Units.TeamID.Blue: current_leaders.append(leader)
			var leader_group = Leader_Group_Class.instance()
			leader_group.add_child(leader)
			var spawn_point = spawn_points[team][i]
			#randomize()
			spawn_point.x += randf() - 0.5
			spawn_point.y += randf() - 0.5
			var battlefield = parent_node.get_node("BattleField")
			Units.call("spawn_one", team, leader_group, battlefield, spawn_point)
			parent_node.get_node("Menu/LeadersInventories").add_inventory(leader)
			parent_node.get_node("Menu/Shop").add_delivery(leader)

	self.emit_signal("leaders_spawned")


