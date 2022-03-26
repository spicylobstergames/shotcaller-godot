extends Node

var selectable:bool = true
var select_shape:CollisionShape2D
var collide:bool = false
var hp:int = 100
var attack:int = 25
var speed:float = 0.5
var current_speed:Vector2 = Vector2.ZERO
var current_destiny:Vector2 = Vector2.ZERO
var angle:float = 0
var att_range:int = 20
var aim_angle:float = 0
var vision:int = 150
var state:String = "idle"
var team:String = "blue"
var type:String = "unit"


func on_move_end():
	pass


func on_idle_end():
	self.move(Vector2(randf()*2000,randf()*2000))


func move(destiny):
	var relative = destiny - self.global_position
	var a = atan2(relative.y, relative.x)
	self.angle = a
	self.current_speed = Vector2(self.speed * cos(a), self.speed * sin(a))
	self.current_destiny = destiny
	self.state = "move"
	self.get_node("animations").current_animation = "move"


func stop():
	self.state = "idle"
	self.get_node("animations").current_animation = "idle"
	self.on_move_end()


func _process(delta):
		# MOVE UNIT
	if self.state == "move":
		self.global_position.x += self.current_speed.x
		self.global_position.y += self.current_speed.y
		var block = self.get_node("collisions/block")
		var d = self.current_destiny
		var u = block.global_position
		var s = block.shape.extents
		# STOP UNIT
		if d.x>=u.x-s.x and d.y>=u.y-s.x and d.x<=u.x+s.x and d.y<=u.y+s.y:
			self.stop()
	
