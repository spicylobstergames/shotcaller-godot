extends Node2D

var selected_unit:Node2D
var selected_leader:Node2D
var selectable_units:Array = []
var all_units:Array = []
var player_team:String = "blue"

var size := 2112
var map
var ui
var unit

func _ready():
	map = get_node("map")
	ui = get_node("ui")
	unit = get_node("map/unit")


func start():
	map.setup_buildings()	
	spawn()


var two := 1

func spawn():
	if two:
		#map.spawn("top", "blue", Vector2(0,0))
		map.spawn("mid", "red", Vector2(1100,1000))
		map.spawn("mid", "blue", Vector2(1000, 980))
		#map.spawn("mid", "blue", Vector2(size,size))
	else:
		for x in range(1, 101):
			map.spawn("top", "blue", Vector2(randf()*size,randf()*size*0.2))
			map.spawn("mid", "blue", Vector2((size*0.3)+randf()*size*0.4,(size*0.3)+randf()*size*0.4))
			map.spawn("bot", "blue", Vector2(randf()*size,(size*0.8)+randf()*size*0.2))



func _process(delta: float) -> void:
	ui.fps.set_text((str(Engine.get_frames_per_second())))
	ui.move_symbols()

	if (ui.update_map_texture): ui.get_map_texture()


var rng = RandomNumberGenerator.new()
func _physics_process(delta):
	rng.randomize()
	
	map.quad.clear()
	
	for unit in all_units:
		if unit.collide: map.quad.add_body(unit)
		if unit.moves and unit.state == "move":
			if circle_point_collision(unit.global_position, unit.current_destiny, unit.collision_rad):
				unit.action = "stop"
	
	for unit in all_units:
		if unit.collide and unit.moves and unit.action != "stop" and unit.state == "move":
			unit.action = "step"
			var neighbors = map.quad.get_bodies_in_radius(unit.global_position, unit.collision_rad+unit.speed)
			for unit2 in neighbors:
				if unit2.collide and unit != unit2 and unit.lane == unit2.lane:
					var next_position = unit.global_position + unit.current_step
					if circle_collision(next_position, unit.collision_rad, unit2.global_position, unit2.collision_rad):
						unit.action = "wait"
						break
		
		match unit.action:
			"stop": unit.stop()
			"step": unit.step()
			"wait": unit.wait()
			



func select(point):
	var unit = get_selected_unit(Vector2(point))
	if unit:
		unselect()
		selected_unit = unit
		if unit.team == player_team and unit.type == "leader":
			selected_leader = unit
		unit.get_node("hud/state").visible = true
		unit.get_node("hud/selection").visible = true
		unit.get_node("hud/hpbar").visible = true
		ui.update_stats()
	

func unselect():
	if selected_unit:
		selected_unit.get_node("hud/state").visible = false
		selected_unit.get_node("hud/selection").visible = false
		selected_unit.get_node("hud/hpbar").visible = false
	selected_unit = null
	selected_leader = null
	ui.update_stats()



func get_selected_unit(point):
	for unit in selectable_units:
		if circle_point_collision(point, unit.global_position,  unit.selection_rad):
			return unit


func circle_point_collision(u1, u2, r):
	return Vector2(u1 - u2).length() < r
	
	
func circle_collision(u1, r1, u2, r2):
	return Vector2(u1 - u2).length() < (r1 + r2)
