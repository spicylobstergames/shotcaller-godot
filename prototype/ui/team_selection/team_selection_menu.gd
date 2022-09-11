extends PanelContainer

onready var leader_select_menu_panel = preload("res://ui/team_selection/leader_select_menu_panel.tscn")
onready var leader_select_menu = preload("res://ui/team_selection/leader_select_panel.tscn")
onready var red_team_container : VBoxContainer = $"%red_team_container"
onready var blue_team_container : VBoxContainer = $"%blue_team_container"

enum Team {
	RED,
	BLUE
}
func _ready():
	$"%add_leader_blue".connect("button_down", self, "handle_add_leader", [Team.BLUE])
	$"%add_leader_red".connect("button_down", self, "handle_add_leader", [Team.RED])
	
	# clear containers (Dummy entries used for visualization)
	for container in [blue_team_container, red_team_container]:
		for child in container.get_children():
			container.remove_child(child)
	
	
func handle_add_leader(team):
	var leader_select_menu_panel_instance = leader_select_menu_panel.instance()
	match team:
		Team.RED:
			leader_select_menu_panel_instance.connect("select_leader",
				self, "handle_select_leader", [leader_select_menu_panel_instance])
			red_team_container.add_child(leader_select_menu_panel_instance)
		Team.BLUE:
			leader_select_menu_panel_instance.connect("select_leader",
				self, "handle_select_leader", [leader_select_menu_panel_instance])
			leader_select_menu_panel_instance.clear_color_remap()
			blue_team_container.add_child(leader_select_menu_panel_instance)

func handle_select_leader(leader_select_panel_instance):
	var menu = leader_select_menu.instance()
	add_child(menu)
	menu.connect("leader_selected", self, "handle_leader_selected", [leader_select_panel_instance, menu])
	
func handle_leader_selected(leader, leader_select_panel_instance, menu):
	menu.queue_free()
	leader_select_panel_instance.leader = leader
	leader_select_panel_instance.prepare()

func get_leaders(team):
	var res = []
	match team:
		Team.RED:
			for child in red_team_container.get_children():
				res.append(child.leader)
		Team.BLUE:
			for child in blue_team_container.get_children():
				res.append(child.leader)
	return res
	

func get_red_team_leaders():
	return get_leaders(Team.RED)

func get_blue_team_leaders():
	return get_leaders(Team.BLUE)
