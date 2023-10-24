extends Control

# self = game

signal game_started
signal game_map_loaded
signal game_resumed
signal game_one_sec_cycle
signal game_paused
signal game_ended

var map:Node2D

var control_state:String = "selection"

@onready var map_manager := $"%map_manager"
@onready var ui := $"%ui"
@onready var selection := $"%selection"
@onready var test := $"%test"
@onready var transitions := $"%transitions"
@onready var spawn :=%spawn

var rng = RandomNumberGenerator.new()


func _ready():
#	Engine.time_scale = 2
	get_tree().paused = false
	WorldState.set_state("is_game_active", false)
	WorldState.set_state("game_started", false)
	WorldState.set_state("show_fps", true)
	WorldState.set_state("player_leaders_names", [])
	WorldState.set_state("enemy_leaders_names", [])
	if test.debug: test.start()
	else: ui.show_main_menu()


func start():
	WorldState.set_state("all_units", [])
	WorldState.set_state("all_buildings", [])
	WorldState.set_state("all_leaders", [])
	WorldState.set_state("selectable_units", [])
	
	WorldState.set_state("player_leaders", [])
	WorldState.set_state("player_buildings", [])
	WorldState.set_state("player_units", [])
	WorldState.set_state("player_extra_unit", "infantry")
	WorldState.set_state("player_kills", 0)
	WorldState.set_state("player_deaths", 0)
	
	WorldState.set_state("enemy_leaders", [])
	WorldState.set_state("enemy_buildings", [])
	WorldState.set_state("enemy_units", [])
	WorldState.set_state("enemy_extra_unit", "infantry")
	WorldState.set_state("enemy_kills", 0)
	WorldState.set_state("enemy_deaths", 0)
	
	WorldState.set_state("neutral_units", [])
	WorldState.set_state("neutral_buildings", [])
	WorldState.set_state("time", 0)
	
	WorldState.set_state("game_started", true)
	WorldState.set_state("is_game_active", false)
	WorldState.set_state("game_ended", false)
	
	setup_timers()
	map_manager.load_current_map()
	ui.hide_version()
	
	if test.debug:
		get_map_texture()
	else:
		transitions.start()
		transitions.transition_completed.connect(get_map_texture)
		
	emit_signal("game_started")


func get_map_texture():
	ui.minimap.update_map_texture = true


func map_loaded():
	if not WorldState.get_state("is_game_active"):
		resume()
		rng.randomize()
		WorldState.one_sec_timer.start()
		spawn.start()
		%soundtrack.stop()
		# game.mode %soundtrack.start()
		emit_signal("game_map_loaded")


func _input(event):
	if WorldState.get_state("game_started"):
		var over_minimap = ui.minimap.over_minimap(event) 
		WorldState.set_state("over_minimap", over_minimap)

		if over_minimap:
			ui.minimap.input(event)
		else:
			ui.active_skills.input(event)
			selection.input(event)

		Crafty_camera.input(event)



func resume():
	get_tree().paused = false
	WorldState.one_sec_timer.paused = false
	WorldState.spawn_timer.paused = false
	ui.show_all()
	ui.hide_menus()
	ui.show_minimap()
	ui.control_panel.show()
	ui.scoreboard.hide()
	WorldState.set_state("is_game_active", true)
	emit_signal("game_resumed")


func pause():
	get_tree().paused = true
	WorldState.one_sec_timer.paused = true
	WorldState.spawn_timer.paused = true
	WorldState.set_state("is_game_active", false)
	emit_signal("game_paused")


func setup_timers():
	WorldState.one_sec_timer = Timer.new()
	WorldState.one_sec_timer.wait_time = 1
	WorldState.one_sec_timer.name = "one_sec_timer"
	WorldState.one_sec_timer.timeout.connect(one_sec_cycle)
	WorldState.add_child(WorldState.one_sec_timer)
	
	WorldState.spawn_timer = Timer.new()
	WorldState.spawn_timer.wait_time = spawn.time
	WorldState.spawn_timer.name = "unit_spawn_timer"
	WorldState.spawn_timer.one_shot = true
	WorldState.add_child(WorldState.spawn_timer)


func one_sec_cycle(): # called every second 
	var time = WorldState.get_state("time") + 1
	WorldState.set_state("time", time)
	
	if not WorldState.get_state("game_ended"):
		var array = [WorldState.get_state("player_kills"), WorldState.get_state("player_deaths"), WorldState.get_state("time"), WorldState.get_state("enemy_kills"), WorldState.get_state("enemy_deaths")]
		ui.top_label.text = "player: %s/%s - time: %s - enemy: %s/%s" % array
		ui.scoreboard.update()
	else:
		ui.top_label.hide()
	
	for unit in WorldState.get_state("all_units"):
		var has_regen = (unit.regen > 0)
		var is_building = (unit.type == "building")
		var is_neutral = (unit.team == "neutral")
		if unit.type == "leader" and not test.debug:
			ui.inventories.update_consumables(unit)
		if can_control(unit): unit.set_delay()
		if ( has_regen and (!is_building or ( is_building and is_neutral )) ):
			unit.set_regen()
			unit.set_dot()
	
	ui.active_skills.one_sec_cycle()
	
	emit_signal("game_one_sec_cycle")


func _process(delta: float) -> void:
	if WorldState.get_state("game_started"):
		Crafty_camera.process(delta)
		ui.process(delta)


func _physics_process(delta: float) -> void:
	if WorldState.get_state("is_game_active"):
		Collisions.physics_process(delta)
		Goap.physics_process(WorldState.get_state("all_units"), delta)


func can_control(unit):
	return (unit 
		and unit.team == WorldState.get_state("player_team")
		and not unit.dead
		and (test.debug or unit.type == "leader")
	)


func end(winner: bool):
	get_tree().paused = true
	WorldState.one_sec_timer.paused = true
	WorldState.spawn_timer.paused = true
	WorldState.set_state("is_game_active", false)
	WorldState.set_state("game_ended", true)
	ui.scoreboard.handle_game_end(winner)
	%soundtrack.play(0.0)
	emit_signal("game_ended")


func reload():
	WorldState.clear_state()
	get_tree().reload_current_scene()


func exit():
	get_tree().quit(0)


func apply_cheat_code(code):
	match code:
		"SHADOW":
			for unit1 in WorldState.get_state("all_units"):
				if unit1.has_node("light"): unit1.get_node("light").shadow_enabled = false
		"WIN":
			end(true)
		"LOSE":
			end(false)

