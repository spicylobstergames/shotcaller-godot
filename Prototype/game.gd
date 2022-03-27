extends Node2D

var selected_unit:Node2D
var selected_leader:Node2D
var selectable_units:Array = []
var collision_blocks:Array = []
var all_units:Array = []
var player_team:String = "blue"

var unit_template:PackedScene = load("res://units/unit.tscn")

func _ready():
#	spawn(Vector2(1000,1000))
#	spawn(Vector2(1060,1000))
	for x in range(20):
		for y in range(20):
			spawn(Vector2(200+x*60,200+y*60))

func _process(delta: float) -> void:
	get_node("ui/top_left/fps").set_text((str(Engine.get_frames_per_second())))

var even = 0
var steps = 16
func _physics_process(delta):
	for i in range(all_units.size()):
		var unit = all_units[i]
		unit.global_position += unit.current_speed
		if i%steps == even: 
			if unit.moves and unit.state == "move":
				var block1 = collision_blocks[i]
				if point_rect_collision(unit.current_destiny, block1):
					unit.stop()
				elif unit.collide:
					for block2 in collision_blocks:
							if block1 != block2 and rect_collision(block1, block2):
								unit.stop()
	even = (even+1)%steps


func spawn(point):
	var unit = unit_template.instance()
	unit.global_position = point
	if unit.selectable: selectable_units.append(unit.get_node("collisions/select"))
	collision_blocks.append(unit.get_node("collisions/block"))
	all_units.append(unit)
	unit.get_node("animations").current_animation = "idle"
	get_node("map").add_child(unit)
	return unit


func point_rect_collision(p, rect):
	var u = rect.global_position
	var s = rect.shape.extents
	return  p.x<=u.x+s.x and p.y<=u.y+s.y and p.x>=u.x-s.x and p.y>=u.y-s.x
	

func rect_collision(rect1, rect2):
	var p1 = rect1.global_position
	var s1 = rect1.shape.extents*2
	var p2 = rect2.global_position
	var s2 = rect2.shape.extents*2
	return p1.x<=p2.x+s2.x and p1.y<=p2.y+s2.y and p1.x+s1.x>=p2.x and p1.y+s1.y>=p2.y

