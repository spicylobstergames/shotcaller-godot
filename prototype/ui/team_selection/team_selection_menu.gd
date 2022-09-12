extends PanelContainer

onready var leader_select_menu_panel = preload("res://ui/team_selection/leader_select_menu_panel.tscn")
onready var leader_select_menu = preload("res://ui/team_selection/leader_select_panel.tscn")
onready var red_team_container : VBoxContainer = $"%red_team_container"
onready var blue_team_container : VBoxContainer = $"%blue_team_container"


func _ready():
	# clear containers (Dummy entries used for visualization)
	for container in [blue_team_container, red_team_container]:
		for child in container.get_children():
			container.remove_child(child)


func handle_add_leader_blue():
	handle_add_leader('blue')

func handle_add_leader_red():
	handle_add_leader('red')


func handle_add_leader(team):
	var panel_instance = leader_select_menu_panel.instance()
	panel_instance.connect("select_leader", self, "handle_select_leader", [panel_instance])
	match team:
		'red':
			red_team_container.add_child(panel_instance)
		'blue':
			panel_instance.clear_color_remap()
			blue_team_container.add_child(panel_instance)
	panel_instance.prepare()


func handle_select_leader(panel_instance):
	var menu = leader_select_menu.instance()
	add_child(menu)
	if panel_instance.team == 'blue': menu.clear_color_remap()
	menu.connect("leader_selected", self, "handle_leader_selected", [panel_instance, menu])


func handle_leader_selected(leader, leader_select_panel_instance, menu):
	menu.queue_free()
	leader_select_panel_instance.leader = leader
	leader_select_panel_instance.prepare()


func get_leaders(team):
	var res = []
	match team:
		'red':
			for child in red_team_container.get_children():
				res.append(child.leader)
		'blue':
			for child in blue_team_container.get_children():
				res.append(child.leader)
	return res
	

func get_red_team_leaders():
	return get_leaders('red')

func get_blue_team_leaders():
	return get_leaders('blue')
