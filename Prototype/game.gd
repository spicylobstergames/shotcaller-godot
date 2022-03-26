extends Node2D

var selected_unit:Node2D
var selected_leader:Node2D
var collision_units:Array = []
var selectable_units:Array = []
var all_units:Array = []
var player_team:String = "blue"


func _ready():
	set_physics_process(false)
	#spawn(Vector2(1000,1000))
	for x in range(32):
		for y in range(32):
			var u = spawn(Vector2(100+x*58,100+y*58))
			u.move(Vector2(randf()*2000,randf()*2000))

func _process(delta: float) -> void:
	#update()
	get_node("ui/top_left/fps").set_text((str(Engine.get_frames_per_second())))
	
#	for unit in all_units:
#		draw_texture(unit.get_node("symbol"), unit.global_position)

#func _draw() -> void:
#	for unit in all_units:
#		draw_texture(unit.sprite, unit.global_position)


var unit_template:PackedScene = load("res://units/unit.tscn")


func spawn(point):
	#var unit:Unit = Unit.new()
	var unit = unit_template.instance()
	unit.global_position = point
	#unit.sprite = unit_source.get_node("sprites")
	if unit.collide: collision_units.append(unit)
	if unit.selectable: selectable_units.append(unit.get_node("collisions/select"))
	all_units.append(unit)
	unit.get_node("animations").current_animation = "idle"
	get_node("map").add_child(unit)
	return unit
