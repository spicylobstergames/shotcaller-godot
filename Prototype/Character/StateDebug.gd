extends Label

func _ready():
	self.visible = ProjectSettings.get("global/debug")
