extends Button

signal select_leader()


func prepare(leader):
	$sprite.prepare(leader)


func _button_down():
	emit_signal("select_leader")
