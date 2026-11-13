extends Control

signal pause_requested
signal resume_requested
signal selection_requested(leader: Unit)

# self = game.ui.dialog


@onready var display_name := $"%display_name"
@onready var msg := $"%msg"
@onready var control_delay := $"%control_delay"
@onready var sprite := $"%sprite"

var can_proceed := false
var can_hide := false

func campaign_start():
	if WorldState.get_state("game_mode") == "campaign":
		var joan = WorldState.get_state("player_leaders")[0]
		show_msg(joan, "We are under attack!")


func show_msg(leader, msg_text):
	pause_requested.emit()
	get_parent().show()
	show()
	can_hide = false
	selection_requested.emit(leader)
	CraftyCamera.focus_unit(leader)
	# animate text
	msg.text = msg_text
	#var sprite = index of leader
	#$panel/portrait/sprite.region_rect.position.x = sprite * 64
	display_name.text = leader.name
	await get_tree().create_timer(0.5).timeout
	can_hide = true


func hide_msg():
	if can_hide:
		hide()
		resume_requested.emit()


func _input(event):
	if event.is_pressed():
		hide_msg()
