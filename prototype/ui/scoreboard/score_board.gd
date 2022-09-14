extends Control

onready var team_red_container = $"%team_red_container"
onready var team_blue_container = $"%team_blue_container"
var entry_scene = preload("res://ui/scoreboard/score_board_entry.tscn")
var is_ready = false

func _ready():
	for container in [team_red_container, team_blue_container]:
		for child in container.get_children():
			container.remove_child(child)
	visible = false

func initialize(red_leaders : Array, blue_leaders : Array):
	for red_leader_index in red_leaders.size():
		var entry = entry_scene.instance()
		team_red_container.add_child(entry)
		entry.initialize_red_leader(red_leaders[red_leader_index])
	for blue_leader_index in blue_leaders.size():
		var entry = entry_scene.instance()
		team_blue_container.add_child(entry)
		entry.initialize_blue_leader(blue_leaders[blue_leader_index])
	is_ready = true
	update()

func _on_update_timer_timeout():
	$update_timer.start()
	update()

func update():
	for container in [team_red_container, team_blue_container]:
		for child in container.get_children():
			child.update()

func _unhandled_input(event):
	if event is InputEventKey:
		if event.echo:
			return
		if event.scancode == KEY_TAB and is_ready:			
			visible = event.is_pressed()
