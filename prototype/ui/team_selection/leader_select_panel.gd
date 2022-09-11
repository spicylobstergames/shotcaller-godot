extends Control

signal leader_selected(leader)

var leaders = ["arthur","bokuden","hongi","lorne","nagato","osman","raja","robin","rollo","sida","takoda","tomyris"]
onready var leader_select_button = preload("res://ui/team_selection/leader_select_button.tscn")
onready var leader_grid = $VBoxContainer/CenterContainer/GridContainer
onready var game = get_tree().get_current_scene()

func _ready():
	for child in leader_grid.get_children():
		leader_grid.remove_child(child)
	for leader in leaders:
		var button = leader_select_button.instance()
		button.prepare(leader)
		leader_grid.add_child(button)
		button.connect("leader_selected", self, "_leader_selected")
	var random_button = leader_select_button.instance()
	random_button.prepare("Random")
	leader_grid.add_child(random_button)
	random_button.connect("leader_selected", self, "_leader_selected")
	

func _leader_selected(leader):
	emit_signal("leader_selected", leader)
