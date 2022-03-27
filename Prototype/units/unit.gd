extends Node

var selectable:bool = true
var selection_rad_sq = 32*32
var selection_offset = Vector2.ZERO
var collide:bool = true
var collision_rad_sq = 16*16
var collision_offset = Vector2.ZERO
var moves:bool = true
var speed:float = 1
var hp:int = 100
var wait:int = 1
var attack:int = 25
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
	self.selection_rad_sq = pow(self.get_node("collisions/select").shape.radius,2)
	self.selection_offset = self.get_node("collisions/select").position
	self.collision_rad_sq = pow(self.get_node("collisions/block").shape.radius,2)
	self.collision_offset = self.get_node("collisions/block").position


func on_move_end():
	pass


func on_idle_end():
	
	if self.wait > 0: self.wait -= 1
	elif self.name != "unit" and not game.two:
		var o = 2000
		var d = Vector2(randf()*o,randf()*o)
		self.move(d)


func move(destiny):
	self.current_destiny = destiny
	self.calc_step()
	self.state = "move"
	self.get_node("animations").current_animation = "move"

func calc_step():
	var distance = self.current_destiny - self.global_position
	var a = atan2(distance.y, distance.x)
	self.angle = a
	self.current_speed = Vector2(self.speed * cos(a), self.speed * sin(a))

func step():
	self.global_position += self.current_speed

func stop():
	self.current_speed = Vector2.ZERO
	self.current_destiny = Vector2.ZERO
	self.state = "idle"
	self.get_node("animations").current_animation = "idle"
	#self.on_move_end()
	
func wait():
	self.wait = game.rng.randi_range(0,3)
	self.state = "idle"
	self.get_node("animations").current_animation = "idle"
