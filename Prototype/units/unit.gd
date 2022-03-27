extends Node

var selectable:bool = true
var select_shape:CollisionShape2D
var moves:bool = true
var collide:bool = true
var hp:int = 100
var attack:int = 25
var speed:float = 1.4
var current_speed:Vector2 = Vector2.ZERO
var current_destiny:Vector2 = Vector2.ZERO
var angle:float = 0
var att_range:int = 20
var aim_angle:float = 0
var vision:int = 150
var state:String = "idle"
var team:String = "blue"
var type:String = "unit"

var game:Node
func _ready():
	game = get_tree().get_current_scene()

func on_move_end():
	pass


func on_idle_end():
	if self.name != "unit":
		var o = 2000
		var d = Vector2(randf()*o,randf()*o)
		self.move(d)


func move(destiny):
	var distance = destiny - self.global_position
	var a = atan2(distance.y, distance.x)
	self.angle = a
	self.current_speed = Vector2(self.speed * cos(a), self.speed * sin(a))
	self.current_destiny = destiny
	self.state = "move"
	self.get_node("animations").current_animation = "move"


func stop():
	self.global_position -= 1 * self.current_speed
	self.current_speed = Vector2.ZERO
	self.state = "idle"
	self.get_node("animations").current_animation = "idle"
	#self.on_move_end()
