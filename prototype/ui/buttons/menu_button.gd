extends Button
var game:Node


export var value:String

var blue_team_button:Node
var red_team_button:Node
var small_map_button:Node
var large_map_button:Node
var play_button:Node

onready var circle_transition_scene : PackedScene = preload("res://ui/circle_transition.tscn")
onready var square_transition_scene : PackedScene = preload("res://ui/square_transition.tscn")


func _ready():
	game = get_tree().get_current_scene()
	yield(get_tree(), "idle_frame")
	
	var menu_buttons = game.ui.main_menu.get_node("container/menu_team_buttons")
	blue_team_button = menu_buttons.get_node("blue_team_button")
	red_team_button = menu_buttons.get_node("red_team_button")
	var map_buttons = game.ui.main_menu.get_node("container/menu_map_buttons")
	small_map_button = map_buttons.get_node("small_map_button")
	large_map_button = map_buttons.get_node("large_map_button")	
	play_button = game.ui.main_menu.get_node("container/play_button")



func button_down():
	match self.value:
		"play":
			game.ui.main_menu.visible = false
			if game.started:
				resume_game()
			else: # new game
				var highlight_button = play_button.get("custom_styles/focus")
				
				# lock selections 
				if blue_team_button.pressed: 
					blue_team_button.set("custom_styles/disabled", highlight_button)
				if red_team_button.pressed: 
					red_team_button.set("custom_styles/disabled", highlight_button)
				
				blue_team_button.disabled = true
				red_team_button.disabled = true
				small_map_button.disabled = true
				large_map_button.disabled = true
				
				game.ui.get_node("mid/team_selection_menu").visible = true

		"choose_leaders":
			var team_selection_menu = game.ui.get_node("mid/team_selection_menu")
			team_selection_menu.visible = false
			if game.player_team == "blue":
				game.player_choose_leaders = team_selection_menu.get_blue_team_leaders()
				game.enemy_choose_leaders = team_selection_menu.get_red_team_leaders()
			else:
				game.player_choose_leaders = team_selection_menu.get_red_team_leaders()
				game.enemy_choose_leaders = team_selection_menu.get_blue_team_leaders()
			game.maps.load_map(game.maps.current_map)
			
			var transition = [square_transition_scene, circle_transition_scene][randi() % 2].instance()
			transition.pause_mode = Node.PAUSE_MODE_PROCESS
			game.get_node("transitions").add_child(transition)
			transition.start_transition()
			yield(transition, "transition_completed")
			game.ui.main_menu_background.visible = false
			transition.queue_free()
			# Transition backward not possible due to how minimap is generated
			# transition.start_transition(true)
			resume_game()
			

			
		"blue":
			game.player_team = "blue"
			game.enemy_team = "red"
			red_team_button.pressed = false
			red_team_button.disabled = false
			blue_team_button.disabled = true
		
		"red":
			game.player_team = "red"
			game.enemy_team = "blue"
			blue_team_button.pressed = false
			blue_team_button.disabled = false
			red_team_button.disabled = true
		
		"small":
			game.maps.current_map = "1lane_map"
			large_map_button.pressed = false
			large_map_button.disabled = false
			small_map_button.disabled = true
		
		"large":
			game.maps.current_map = "3lane_map"
			small_map_button.pressed = false
			small_map_button.disabled = false
			large_map_button.disabled = true
		
		"menu":
			game.paused = true
			get_tree().paused = true
			Behavior.spawn.timer.paused = true
			game.ui.hide_all()
			game.ui.get_node('mid').visible = true
			game.ui.minimap.visible = false
			game.ui.get_node("mid/team_selection_menu").visible = false
			game.ui.main_menu_background.visible = true
			game.ui.main_menu.visible = true
		
		"shop":
			game.ui.shop.visible = !game.ui.shop.visible
			game.ui.inventories.update_buttons()
			if game.ui.shop.visible:
				game.ui.shop.update_buttons()
				game.ui.controls_menu.visible = false
				game.ui.orders_menu.visible = false
			game.ui.buttons_update()
		
		
		"orders":
			game.ui.orders_menu.visible = !game.ui.orders_menu.visible
			if game.ui.orders_menu.visible:
				game.ui.shop.visible = false
				game.ui.controls_menu.visible = false
				game.ui.inventories.update_buttons() # hide sell bt
			game.ui.buttons_update()
		
		
		"controls":
			game.ui.controls_menu.visible = !game.ui.controls_menu.visible
			if game.ui.controls_menu.visible:
				game.ui.shop.visible = false
				game.ui.orders_menu.visible = false
				game.ui.inventories.update_buttons() # hide sell bt
			else: game.control_state = "selection"
			game.ui.buttons_update()

func resume_game():
	game.ui.main_menu_background.visible = false
	game.paused = false
	get_tree().paused = false
	Behavior.spawn.timer.paused = false;
	game.ui.show_all()
	game.ui.get_node('mid').visible = false
	game.ui.minimap.visible = true
	game.ui.main_menu_background.visible = false
	game.ui.main_menu.visible = false
	game.ui.get_node("score_board").visible = false
