extends Control

var leaders = ["arthur","bokuden","hongi","lorne","nagato","osman","raja","robin","rollo","sida","takoda","tomyris"]
onready var leader_select_button = preload("res://ui/buttons/leader_select_button.tscn")
onready var leader_grid = $VBoxContainer/CenterContainer/GridContainer
onready var selected_leader_container = $VBoxContainer/selected_leader_container
onready var game = get_tree().get_current_scene()

func _ready():
	for child in leader_grid.get_children():
		leader_grid.remove_child(child)
	for leader in leaders:
		var button = leader_select_button.instance()
		button.prepare(leader)
		leader_grid.add_child(button)
		button.connect("leader_selected", self, "_leader_selected")
	selected_leader_container.visible = false
	$VBoxContainer/no_leader_selected_label.visible = true
	

func _leader_selected(leader):
	$VBoxContainer/no_leader_selected_label.visible = false
	selected_leader_container.visible = true
	selected_leader_container.get_node("PanelContainer/HBoxContainer/MarginContainer/sprite").prepare(leader)
	selected_leader_container.get_node("PanelContainer/HBoxContainer/Label").text = leader
	game.player_choose_leaders = [leader]
