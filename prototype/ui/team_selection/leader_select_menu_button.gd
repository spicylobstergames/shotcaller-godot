extends Button

signal select_leader()

func _ready():
	connect("button_down", self, "_button_down")
	$touch_button.connect("pressed", self, "_button_down")

func prepare(leader):
	$sprite.prepare(leader)
	
func _button_down():
	emit_signal("select_leader")
