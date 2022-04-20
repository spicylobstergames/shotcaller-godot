extends Button
var game:Node



export var value:String



func _ready():
	game = get_tree().get_current_scene()



func button_down():
	match self.value:
		"play":
			get_tree().paused = false
			game.ui.main_menu.hide()
			game.ui.buttons.show()
			game.ui.leaders_icons.show()
			game.start()
			
		
