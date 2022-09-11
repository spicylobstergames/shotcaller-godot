extends Button

signal leader_selected(leader)

func _ready():
	connect("button_down", self, "_button_down")
	$touch_button.connect("pressed", self, "_button_down")

func prepare(leader):
	$sprite.prepare(leader)
	$name.text = leader
	
func _button_down():
	emit_signal("leader_selected", $name.text)
