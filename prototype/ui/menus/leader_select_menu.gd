extends Control

signal leader_selected

@onready var leader_button = preload("res://ui/buttons/leader_button.tscn")

@onready var leaders_container = $"%leaders_container"
@onready var leader_preview = $"%leader_preview"

var team := "red"

func _ready():
	# clear placeholders
	for child in leaders_container.get_children():
		leaders_container.remove_child(child)
		child.queue_free()
	# creates leader buttons
	for leader in WorldState.leaders:
		var button = leader_button.instantiate()
		leaders_container.add_child(button)
		button.prepare(leader)
		format_button(button)
	# random leader button
	var random_button = leader_button.instantiate()
	leaders_container.add_child(random_button)
	random_button.prepare("random")
	format_button(random_button)


func format_button(button):
	button.hpbar.hide()
	button.hint.hide()
	button.pressed.connect(show_preview.bind(button))


func show_preview(button):
	var leader = button.name_label.text
	leader_preview.prepare(leader)
	leader_preview.show()
	button.button_pressed = false


func color_remap(new_team):
	team = new_team
	for child in leaders_container.get_children():
		child.color_remap(team)


func preview_confirm(leader_name):
	hide()
	leader_preview.hide()
	emit_signal("leader_selected", leader_name, team)
