extends PanelContainer

signal change_leader

var leader:String = "random"
var team:String = "red"

onready var leader_name = $"%leader_name"
onready var leader_button = $"%leader_button"


func prepare(new_leader, new_team):
	leader = new_leader
	team = new_team
	leader_button.prepare(leader, team)
	leader_button.hpbar.hide()
	leader_button.name_label.hide()
	leader_button.hint.hide()
	leader_name.text = leader


func change_leader_pressed():
	emit_signal("change_leader")
	queue_free()


func _on_x_button_pressed():
	queue_free()
