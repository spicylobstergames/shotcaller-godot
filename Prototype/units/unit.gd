extends Node

var game:Node

export var hp:int = 100
var current_hp:int = 100
export var vision:int = 150
var current_vision:int = 150
export var type:String = "creep"
export var subtype:String = "melee"
export var team:String = "blue"
var mirror:bool = false

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
export var attacks:bool = true
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
var behavior:String = "stand" # "stop", "move", "attack", "move_and_attack"
var state:String = "idle" # "move", "attack", "death"

var move
var attack
var ai

func _ready():
	game = get_tree().get_current_scene()
	move = get_node("behavior/move")
	attack = get_node("behavior/attack")
	ai = get_node("behavior/ai")


func set_state(s):
	self.state = s
	self.get_node("animations").current_animation = s


func set_behavior(s):
	self.behavior = s
	self.get_node("hud/state").text = s


func mirror_toggle(on):
	self.mirror = on
	if on:
		self.get_node("sprites").scale.x = -1
		if self.has_node("collisions/attack"):
			self.get_node("collisions/attack").position.x = -1 * abs(self.get_node("collisions/attack").position.x)
	else:
		self.get_node("sprites").scale.x = 1
		if self.has_node("collisions/attack"):
			self.get_node("collisions/attack").position.x = abs(self.get_node("collisions/attack").position.x)


func look_at(point):
	self.mirror_toggle(point.x - self.global_position.x < 0)


func get_units_on_sight(filters):
	var neighbors = game.map.quad.get_units_in_radius(self.global_position, self.current_vision)
	var targets = []
	for unit2 in neighbors:
		var distance = self.global_position.distance_to(unit2.global_position)
		if self != unit2 and distance < self.current_vision:
			if not filters: targets.append(unit2)
			else:
				for filter in filters:
					if unit2[filter] == filters[filter]:
						targets.append(unit2)
	return targets


func wait():
	#self.wait_time = game.rng.randi_range(0.6,3)
	self.set_state("idle")


func on_idle_end():
	if self.wait_time > 0: self.wait_time -= 1
	else:
		game.unit.move.resume(self)
		game.unit.ai.resume(self)
	
		if game.stress_test:
			var o = 2000
			var d = Vector2(randf()*o,randf()*o)
			game.unit.ai.move_and_attack(self, d)



func on_move():
	game.unit.move.step(self)


func on_collision():
	game.unit.move.on_collision(self)


func on_move_end():
	game.unit.ai.resume(self)


func on_arrive():
	game.unit.ai.end(self)
	game.unit.move.end(self)



func on_attack_end():
	game.unit.attack.end(self)
	game.unit.ai.resume(self)


func die():
	self.set_state("death")
	self.set_behavior("stop")
	game.all_units.erase(self)


func on_death_end():
	self.global_position = Vector2(-1000, -1000)
	self.visible = false


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
		"sprite": body,
		"data": texture,
		"region": region,
		"scale": scale
	}
