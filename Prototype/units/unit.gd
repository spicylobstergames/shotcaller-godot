extends Node

var game:Node

export var hp:int = 100
var current_hp:int = 100
export var vision:int = 150
var current_vision:int = 150
export var type:String = "creep"
export var subtype:String = "melee"
var team:String = "blue"
var mirror:bool = true

# SELECTION
export var selectable:bool = true
var selection_radius = 36
var selection_position:Vector2 = Vector2.ZERO

# MOVEMENT
export var moves:bool = true
export var speed:float = 1
var current_speed:float = 1
var angle:float = 0
var current_step:Vector2 = Vector2.ZERO
var current_destiny:Vector2 = Vector2.ZERO

# COLLISION
export var collide:bool = true
var collision_radius = 10
var collision_position:Vector2 = Vector2.ZERO

# ATTACK
export var damage:int = 25
var current_damage:int = 25
export var attack_range:int = 1
var current_attack_range:int = 1
export var attack_speed:int = 1
var current_attack_speed:int = 1
var aim_angle:float = 0
var target:Node2D
var attack_hit_position:Vector2 = Vector2.ONE
var attack_hit_radius = 24

# AI
var next_event:String = "" # "on_arive" "on_move" "on_collision"
var objective:Vector2 = Vector2.ZERO
var wait_time:int = 0
var lane:String = "mid"
var behavior:String = "wait" # "stand", "move", "attack", "move_and_attack"
var state:String = "idle" # "move", "attack"

var move
var attack
var ai

func _ready():
	game = get_tree().get_current_scene()
	move = get_node("move")
	attack = get_node("attack")
	ai = get_node("ai")


func set_state(s):
	self.state = s
	self.get_node("hud/state").text = s
	self.get_node("animations").current_animation = s


func look_at(point):
	self.mirror = point.x - self.global_position.x < 0
	self.get_node("sprites").scale.x = -1 if self.mirror else 1


func get_units_on_sight():
	var neighbors = game.map.quad.get_units_in_radius(self.global_position, self.current_vision)
	var targets = []
	for unit2 in neighbors:
		if self != unit2 and (self.global_position - unit2.global_position).length() < self.current_vision:
			targets.append(unit2)
	return targets


func wait():
	#if not game.stress_test: self.wait_time = game.rng.randi_range(1,4)
	self.set_state("idle")


func on_move():
	game.unit.move.step(self)
	
	
func on_move_end():
	game.unit.ai.on_move_end(self)


func on_collision():
	game.unit.ai.on_collision(self)


func on_idle_end():
	if self.wait_time > 0: self.wait_time -= 1
	elif game.stress_test:
		var o = 2000
		var d = Vector2(randf()*o,randf()*o)
		game.unit.move.start(self, d)


func on_arrive():
	game.unit.ai.on_arrive(self)
	game.unit.move.end(self)


func on_attack_end():
	game.unit.attack.end(self)



func die():
	self.set_state("dead")


func get_texture():
	var body = get_node("sprites/body")
	var texture
	var region
	var scale
	if body is Sprite: 
		texture = body.texture 
		region = body.region_rect
		match self.subtype:
			"tower": scale = Vector2(0.9,0.9)
			"barrack": scale = Vector2(0.7,0.7)
			"core": scale = Vector2(0.55,0.55)
	else:
		texture = body.frames.get_frame('default', 0)
		region = texture.region
		scale = Vector2(3,3)
		
	return {
		"data": texture,
		"region": region,
		"scale": scale
	}
