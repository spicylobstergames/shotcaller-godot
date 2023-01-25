extends Control

# self = game.ui.scoreboard

onready var team_red_container = $"%team_red_container"
onready var team_blue_container = $"%team_blue_container"
var entry_scene = preload("res://ui/scoreboard/scoreboard_entry.tscn")
var is_ready = false

func _ready():
	for container in [team_red_container, team_blue_container]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	visible = false


func build(red_leaders : Array, blue_leaders : Array):
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


func handle_game_end(winner):
	is_ready = false
	visible = true
	$update_timer.stop()
	$"%result_label".text = "Victory" if winner else "DEFEAT"
	$"%result_label".visible = true
	$"%restart_button".visible = true


func _on_restart_button_pressed():
# warning-ignore:return_value_discarded
	get_tree().reload_current_scene()
