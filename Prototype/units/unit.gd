extends Node
var game:Node

export var hp:int = 100
var current_hp:int = 100
export var vision:int = 100
var current_vision:int = 100
export var type:String = "pawn" # building leader
export var subtype:String = "infantry" # archer mounted
export var display_name:String
export var title:String
export var team:String = "blue"
var dead:bool = false
var mirror:bool = false

# SELECTION
export var selectable:bool = false
var selection_radius = 36
var selection_position:Vector2 = Vector2.ZERO

# MOVEMENT
export var moves:bool = false
export var speed:float = 0
var current_speed:float = 0
var angle:float = 0
var current_step:Vector2 = Vector2.ZERO
var current_destiny:Vector2 = Vector2.ZERO
var last_position:Vector2 = Vector2.ZERO
var last_position2:Vector2 = Vector2.ZERO
var current_path:Array = []

# COLLISION
export var collide:bool = false
var collision_radius = 0
var collision_position:Vector2 = Vector2.ZERO
var collide_target:Node2D
var collision_timer

# ATTACK
export var attacks:bool = false
export var ranged:bool = false
export var damage:int = 0
var current_damage:int = 0
export var attack_range:int = 1
var current_attack_range:int = 1
export var attack_speed:float = 1
var current_attack_speed:float = 1
var target:Node2D
var weapon:Node2D

# PROJECTILES
var projectile:Node2D # template
var projectiles:Array = []
export var projectile_speed:float = 3
export var projectile_rotation:float = 0
var attack_hit_position:Vector2 = Vector2.ONE
var attack_hit_radius = 24

# ADVANCE
var next_event:String = "" # "on_arive" "on_move" "on_collision"
var objective:Vector2 = Vector2.ZERO
var wait_time:int = 0
export var lane:String = "mid"
var behavior:String = "stand" # "move", "attack", "advance", "stop"
var state:String = "idle" # "move", "attack", "death"
var priority = ["leader", "pawn", "building"]

var hud:Node
var spawn:Node
var move:Node
var attack:Node
var advance:Node
var path:Node
var orders:Node

func _ready():
	game = get_tree().get_current_scene()
	
	if has_node("hud"): hud = get_node("hud")
	if has_node("behavior/spawn"): spawn = get_node("behavior/spawn")
	if has_node("behavior/move"): move = get_node("behavior/move")
	if has_node("behavior/attack"): attack = get_node("behavior/attack")
	if has_node("behavior/advance"): advance = get_node("behavior/advance")
	if has_node("behavior/path"): path = get_node("behavior/path")
	if has_node("behavior/orders"): orders = get_node("behavior/orders")
	if has_node("sprites/weapon"): weapon = get_node("sprites/weapon")
	if has_node("sprites/weapon/projectile"): projectile = get_node("sprites/weapon/projectile")



func reset_unit():
	self.setup_team()
	if self.type == "leader": self.get_node("hud/state").text = self.name
	else: self.get_node("hud/state").text = self.subtype
	self.current_hp = self.hp
	self.current_attack_range = self.attack_range
	self.current_vision = self.vision
	self.current_speed = self.speed
	self.current_damage = self.damage
	self.current_attack_speed = self.attack_speed
	self.visible = true
	self.get_node("hud").update_hpbar(self)


func set_state(s):
	if not self.dead:
		self.state = s
		self.get_node("animations").current_animation = s


func set_behavior(s):
	self.behavior = s
	#self.get_node("hud/state").text = s


func setup_team():
	var is_red = self.team == "red"
	# MIRROR
	if self.type != "building":
		self.mirror_toggle(is_red)
	# COLORS
	var texture = self.get_texture()
	if not is_red and texture.sprite.material:
		texture.sprite.material = null
	else:
		texture.sprite.material = get_node("sprites/sprite").material
	# FLAGS
	if self.type == "building":
		if not is_red:
			var flags = self.get_node("sprites/flags").get_children()
			for flag in flags:
				var flag_sprite = flag.get_node("sprite")
				var material = flag_sprite.material.duplicate()
				material.set_shader_param("change_color", false)
				flag_sprite.material = material


func oponent_team():
	var t = "blue"
	if self.team == t: t = "red"
	return t



func get_name():
	if self.type == "leader":
		return "%s %s" % [self.display_name, self.title]
	else: return "%s (%s)" % [self.subtype, self.type]


func look_at(point):
	self.mirror_toggle(point.x - self.global_position.x < 0)


func mirror_toggle(on):
	self.mirror = on
	if on:
		if self.type == "building":
			self.get_node("sprites/body").scale.x = -1
			self.get_node("sprites/flags").scale.x = -1
		self.get_node("sprites").scale.x = -1
		if self.attack_hit_position:
			self.attack_hit_position.x = -1 * abs(self.attack_hit_position.x)
	else:
		if self.type == "building":
			self.get_node("sprites/body").scale.x = 1
			self.get_node("sprites/flags").scale.x = 1
		self.get_node("sprites").scale.x = 1
		if self.attack_hit_position:
			self.attack_hit_position.x = abs(self.attack_hit_position.x)


func get_texture():
	var body = get_node("sprites/body")
	var texture
	var region
	var scale
	if body is Sprite: 
		texture = body.texture 
		region = body.region_rect
		match self.subtype:
			"tower": scale = Vector2(1,1)
			"barrack": scale = Vector2(0.8,0.8)
			"castle": scale = Vector2(0.6,0.6)
	else:
		texture = body.frames.get_frame('default', 0)
		region = texture.region
		scale = Vector2(2.5,2.5)
		match self.name:
			"takoda": scale = Vector2(1.8,1.8)
			"tomyris": scale = Vector2(1.8,1.8)
		
	return {
		"sprite": body,
		"data": texture,
		"mirror": self.mirror,
		"material": body.material,
		"region": region,
		"scale": scale
	}


func get_units_on_sight(filters):
	var neighbors = game.map.blocks.get_units_in_radius(self.global_position, self.current_vision)
	var targets = []
	for unit2 in neighbors:
		if unit2.hp:
			var distance = self.global_position.distance_to(unit2.global_position)
			if self != unit2 and distance < self.current_vision:
				if not filters: targets.append(unit2)
				else:
					for filter in filters:
						if unit2[filter] == filters[filter]:
							targets.append(unit2)
	return targets


func setup_collisions(unit):
	if unit.has_node("collisions/select"):
		unit.selection_position = unit.get_node("collisions/select").position
		unit.selection_radius = unit.get_node("collisions/select").shape.radius
	
	if unit.has_node("collisions/block"):
		unit.collision_position = unit.get_node("collisions/block").position
		unit.collision_radius = unit.get_node("collisions/block").shape.radius
	
	if unit.has_node("collisions/attack"):
		unit.attack_hit_position = unit.get_node("collisions/attack").position
		unit.attack_hit_radius = unit.get_node("collisions/attack").shape.radius



func wait():
	self.wait_time = game.rng.randi_range(1,4)
	self.set_state("idle")


func on_idle_end(): # every idle animation end (0.6s)
	advance.on_idle_end(self)
	if self.wait_time > 0: self.wait_time -= 1
	else: game.test.unit_wait_end(self)


func on_move(delta): # every frame if there's no collision
	move.step(self, delta)


func on_collision(delta):
	if self.moves: 
		move.on_collision(self, delta)
		if self.attacks: 
			advance.on_collision(self)


func on_move_end(): # every move animation end (0.6s for speed = 1)
	if self.moves and self.attacks: 
		advance.resume(self)


func on_arrive(): # when collides with destiny
	if self.current_path.size() > 0:
		path.follow_next(self)
	elif self.moves:
		move.end(self)
		if self.attacks: 
			advance.end(self)


func on_attack_release(): # every ranged projectile start
	attack.projectile_start(self)
	advance.resume(self)


func on_attack_hit():  # every melee attack animation end (0.6s for ats = 1)
	if self.attacks: 
		attack.hit(self)
		if self.moves:
			advance.resume(self)


func die():  # hp <= 0
	self.set_state("death")
	self.set_behavior("stand")
	self.dead = true


func on_death_end():  # death animation end
	self.global_position = Vector2(-1000, -1000)
	self.visible = false
	if not game.test.stress:
		match self.type:
			"pawn":
				game.unit.spawn.cemitery[self.subtype].append(self)
			"leader":
				match self.team:
					game.player_team:
						game.unit.spawn.cemitery.player_leaders.append(self)
					game.enemy_team:
						game.unit.spawn.cemitery.enemy_leaders.append(self)
						
	else: game.test.respawn(self)
