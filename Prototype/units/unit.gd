extends Node
var game:Node

export var hp:int = 100
export var vision:int = 150
export var type:String = "unit"
var team:String = "blue"
var mirror:bool = true
# SELECTION
export var selectable:bool = true
var selection_rad = 36
var selection_rad_sq = 36*36
# MOVEMENT
export var moves:bool = true
export var speed:float = 1
var angle:float = 0
var current_speed:Vector2 = Vector2.ZERO
var current_destiny:Vector2 = Vector2.ZERO
# COLLISION
export var collide:bool = true
var collision_rad = 10
# ATTACK
export var damage:int = 25
export var attack_range:int = 1
export var attack_speed:int = 1
var aim_angle:float = 0
var target:Node2D
var attack_hit_position:Vector2 = Vector2.ONE
var attack_hit_radius = 24
# BEHAVIOR
var objective:Vector2 = Vector2.ZERO
var wait_time:int = 1
var state:String = "idle"
var action:String = "wait"
var lane:String = "mid"

var unit_template:PackedScene = load("res://units/creeps/melee.tscn")

func _ready():
	game = get_tree().get_current_scene()
	
	self.selection_rad = self.get_node("collisions/select").shape.radius
	self.collision_rad = self.get_node("collisions/block").shape.radius
	
	if self.has_node("collisions/attack"):
		self.attack_hit_position = self.get_node("collisions/attack").position
		self.attack_hit_radius = self.get_node("collisions/attack").shape.radius


func spawn(lane, team, point):
	var unit = unit_template.instance()
	unit.lane = lane
	unit.team = team
	unit.global_position = point
	if unit.selectable: game.selectable_units.append(unit)
	game.all_units.append(unit)
	unit.get_node("animations").current_animation = "idle"
	var symbol = unit.get_node("symbol").duplicate()
	symbol.visible = true
	symbol.scale *= 0.25
	game.ui.map_symbols.add_child(symbol)
	game.get_node("map").add_child(unit)
	return unit


func set_state(s):
	self.state = s
	self.get_node("hud/state").text = s
	self.get_node("animations").current_animation = s



func move(destiny):
	self.current_destiny = destiny
	self.calc_step()
	self.set_state("move")
	self.action = "move"


func attack(point):
	self.look_at(point)
	self.set_state("attack")
	self.action = "attack"


func move_and_attack(point):
	self.objective = point
	if self.state != "attack":
		var enemies = self.get_units_on_sight()
		if enemies: 
			self.target = enemies[0] # todo closest enemy
			if self.hits(self.target):
				self.attack(self.target.global_position)
			else: self.move(self.target.global_position)
		else: self.move(point)





func calc_step():
	if self.speed > 0:
		var distance = self.current_destiny - self.global_position
		self.angle = distance.angle()
		self.current_speed = Vector2(self.speed * cos(self.angle), self.speed * sin(self.angle))


func look_at(point):
	self.mirror = point.x - self.global_position.x < 0
	self.get_node("sprites").scale.x = -1 if self.mirror else 1


func step():
	self.global_position += self.current_speed


func stop():
	self.current_speed = Vector2.ZERO
	self.current_destiny = Vector2.ZERO
	if self.objective: self.move_and_attack(self.objective)
	else: self.set_state("idle")


func wait():
	self.wait_time = game.rng.randi_range(0,3)
	self.set_state("idle")


func on_idle_end():
	if not game.two:
		if self.wait_time > 0 and game.two: self.wait_time -= 1
		elif self.name != "unit":
			var o = 2000
			var d = Vector2(randf()*o,randf()*o)
			self.move(d)


func get_units_on_sight():
	var neighbors = game.quad[self.lane].get_bodies_in_radius(self.global_position, self.vision)
	var targets = []
	for unit2 in neighbors:
		if self != unit2 and (self.global_position - unit2.global_position).length() < self.vision:
			targets.append(unit2)
	return targets



func on_attack_end():
	var neighbors = game.quad[self.lane].get_bodies_in_radius(self.attack_hit_position, self.attack_hit_radius)
	for unit2 in neighbors:
		if self.hits(unit2):
			unit2.take_hit(self.damage)
	self.set_state("idle")


func hits(unit2):
	var attack_position = self.global_position + self.attack_hit_position
	var attack_radius = self.attack_hit_radius * self.attack_range
	return game.circle_collision(attack_position, attack_radius, unit2.global_position, unit2.collision_rad)


func take_hit(dmg):
	print("hit")
	self.hp -= dmg
	if self.hp <= 0: self.die()


func die():
	self.set_state("dead")
