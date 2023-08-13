extends Control

# self = game.ui.new_game_menu

@onready var game = get_tree().get_current_scene()

@onready var leader_select_item = preload("leader_selection/leader_select_item.tscn")

@onready var red_team_container : VBoxContainer = $"%red_team_container"
@onready var blue_team_container : VBoxContainer = $"%blue_team_container"


func _ready():
	# clear containers (Dummy entries used for visualization)
	for container in [blue_team_container, red_team_container]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()


func choose_leader(team):
	var select_menu = game.ui.leader_select_menu
	select_menu.color_remap(team)
	hide()
	select_menu.show()


func add_leader(leader, team):
	show()
	var leader_item = leader_select_item.instantiate()
	match team:
		"red":
			red_team_container.add_child(leader_item)
		"blue":
			blue_team_container.add_child(leader_item)
	
	leader_item.prepare(leader, team)
	leader_item.change_leader.connect(choose_leader.bind(team))


func get_leaders(team):
	var res = []
	match team:
		"red":
			for child in red_team_container.get_children():
				res.append(child.leader)
		"blue":
			for child in blue_team_container.get_children():
				res.append(child.leader)
	return res


func get_selected_map():
	if $"%1_lane_checkbox".is_pressed():
		return "one_lane_map"
	else:
		return "three_lane_map"


func get_player_team():
	if $"%blue_team_checkbox".is_pressed():
		return "blue"
	else:
		return "red"


func _on_start_game_button_pressed():
	hide()
	
	game.map_manager.current_map = get_selected_map()
	var player_team = get_player_team()
	WorldState.set_state("player_team", player_team)
		
	var blue_team_leaders = get_leaders("blue")
	var red_team_leaders = get_leaders("red")
	
	if player_team == "blue":
		WorldState.set_state("enemy_team", "red")
		WorldState.set_state("player_leaders_names", blue_team_leaders)
		WorldState.set_state("enemy_leaders_names", red_team_leaders)
	else:
		WorldState.set_state("enemy_team", "blue")
		WorldState.set_state("player_leaders_names", red_team_leaders)
		WorldState.set_state("enemy_leaders_names", blue_team_leaders)
	
	WorldState.set_state("game_mode", "match")
	game.start()


func _on_back_button_pressed():
	hide()
	game.ui.show_main_menu()
