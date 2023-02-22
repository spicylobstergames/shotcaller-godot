extends PanelContainer

var leader:String = "random"
var team:String = "red"

signal select_leader()

func prepare():
	var button = $HBoxContainer/leader_button
	var sprite = button.get_node("sprite")
	
	$HBoxContainer/leader_name.text = leader


func clear_color_remap():
	team = "blue"
	$HBoxContainer/leader_button/sprite.material = null


func _select_leader():
	emit_signal("select_leader")


func _on_x_button_pressed():
	queue_free()
