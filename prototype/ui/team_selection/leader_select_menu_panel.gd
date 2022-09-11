extends PanelContainer

var leader = "Random"

signal select_leader()

func _ready():
	$HBoxContainer/button.connect("select_leader", self, "on_select_leader")
	prepare()

func prepare():
	$HBoxContainer/button.prepare(leader)
	$HBoxContainer/Label.text = leader

func on_select_leader():
	emit_signal("select_leader")

func clear_color_remap():
	$HBoxContainer/button/sprite.material = null
