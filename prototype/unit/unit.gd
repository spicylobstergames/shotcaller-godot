extends Node
var game:Node

# self = game.unit.orders

export var hp:int = 100
var current_hp:int = 100
export var regen:int = 1
var current_regen:int = 1
export var vision:int = 100
var current_vision:int = 100
export var type:String = "pawn" # building leader
export var subtype:String = "melee" # ranged mounted base lane backwood
export var display_name:String
export var title:String
export var team:String = "blue"
export var respawn:float = 1
var dead:bool = false
var mirror:bool = false
var texture:Dictionary


# SELECTION
export var selectable:bool = false
var selection_radius = 36
var selection_position:Vector2 = Vector2.ZERO

# MOVEMENT
export var moves:bool = false
export var speed:float = 0
var current_speed:float = 0
var angle:float = 0
var origin:Vector2 = Vector2.ZERO
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
var stunned:bool = false
export var damage:int = 0
var current_damage:int = 0
export var attack_range:int = 1
var current_attack_range:int = 1
export var attack_speed:float = 1
var current_attack_speed:float = 1
var target:Node2D
var last_target:Node2D
var attack_count = 0
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
var tactics:String = "default" # aggresive defensive retreat 
var retreating = false


var hud:Node
var spawn:Node
var move:Node
var attack:Node
var advance:Node
var path:Node
var orders:Node
var skills:Node

func _ready():
	game = get_tree().get_current_scene()
	
	if has_node("hud"): hud = get_node("hud")
	if has_node("behavior/spawn"): spawn = get_node("behavior/spawn")
	if has_node("behavior/move"): move = get_node("behavior/move")
	if has_node("behavior/attack"): attack = get_node("behavior/attack")
	if has_node("behavior/advance"): advance = get_node("behavior/advance")
	if has_node("behavior/path"): path = get_node("behavior/path")
	if has_node("behavior/orders"): orders = get_node("behavior/orders")
	if has_node("behavior/skills"): skills = get_node("behavior/skills")
	
	if has_node("sprites/weapon"): weapon = get_node("sprites/weapon")
	if has_node("sprites/weapon/projectile"): projectile = get_node("sprites/weapon/projectile")



func reset_unit():
	self.setup_team()
	
	if self.type == "leader": 
		self.hud.state.visible = true
		self.hud.hpbar.visible = true
	
	self.hud.state.text = self.display_name
	self.current_hp = self.hp
	self.current_attack_range = self.attack_range
	self.current_vision = self.vision
	self.current_speed = self.speed
	self.current_damage = self.damage
	self.current_attack_speed = self.attack_speed
	self.visible = true
	self.stunned = false
	self.hud.update_hpbar(self)
	game.ui.minimap.setup_symbol(self)


func set_state(s):
	if not self.dead:
		self.state = s
		self.get_node("animations").current_animation = s


func set_behavior(s):
	self.behavior = s
	#self.get_node("hud/state").text = s


func setup_team():
	var is_red = (self.team == "red")
	var is_blue = (self.team == "blue")
	var is_neutral = (self.team == "neutral")
	# COLORS
	get_texture()
	
	if is_blue:
		self.texture.sprite.material = null
	if is_red:
		self.texture.sprite.material = get_node("sprites/sprite").material
	if is_neutral:
		self.texture.sprite.material = get_node("sprites/neutral").material
	
	# MIRROR
	if self.type != "building": 
		self.mirror_toggle(is_red)
	else: # BLUE FLAGS
		if is_blue:
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


func look_at(point):
	self.mirror_toggle(point.x - self.global_position.x < 0)


func mirror_toggle(on):
	self.mirror = on
	var s = -1 if on else 1
	self.get_node("sprites").scale.x = s
	if self.attack_hit_position:
		self.attack_hit_position.x = s * abs(self.attack_hit_position.x)



func get_texture():
	if not self.texture:
		var body = get_node("sprites/body")
		var texture_data
		var region
		var scale = Vector2(1,1)
		var material
		if self.team == "red": material = body.material
		if body is Sprite: 
			texture_data = body.texture 
			region = body.region_rect
			match self.subtype:
				"tower": scale = Vector2(1,1)
				"barrack": scale = Vector2(0.9,0.9)
				"castle": scale = Vector2(0.8,0.8)
		else:
			texture_data = body.frames.get_frame('default', 0)
			region = texture_data.region
			scale = Vector2(2.5,2.5)
			match self.subtype:
				"mounted": scale = Vector2(1.8,1.8)
		self.texture = {
			"sprite": body,
			"data": texture_data,
			"mirror": self.mirror,
			"material": material,
			"region": region,
			"scale": scale
		}
	return self.texture


func get_units_on_sight(filters):
	var neighbors = game.map.blocks.get_units_in_radius(self.global_position, self.current_vision)
	var targets = []
	for unit2 in neighbors:
		if unit2.hp and self != unit2 and not unit2.dead:
			var distance = self.global_position.distance_to(unit2.global_position)
			if distance < self.current_vision:
				if not filters: targets.append(unit2)
				else:
					for filter in filters:
						if unit2[filter] == filters[filter]:
							targets.append(unit2)
	return targets



func get_gold():
	if self.name in game.ui.inventories.leaders:
		return game.ui.inventories.leaders[self.name].gold


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
	if self.moves:
		if self.attacks: 
			advance.resume(self)


func on_arrive(): # when collides with destiny
	if self.current_path.size() > 0:
		path.follow_next(self)
	elif self.moves:
		move.end(self)
		if self.attacks: 
			advance.end(self)


func on_attack_release(): # every ranged projectile start
	attack.projectile_release(self)
	advance.resume(self)

func on_attack_hit():  # every melee attack animation end (0.6s for ats = 1)
	if self.attacks: 
		attack.hit(self)
		if self.moves:
			advance.resume(self)


func stun_start():
	self.wait_time = 2
	self.stunned = true
	self.set_state("stun")


func on_stun_end():
	if self.wait_time > 1: self.wait_time -= 1
	else:
		self.stunned = false
		if self.behavior == "move":
			move.resume(self)
		if self.behavior == "advance":
			advance.resume(self)
		if self.behavior == "stand" or self.behavior == "stop":
			self.set_state("idle")


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
				game.unit.spawn.cemitery_add_pawn(self)
			"leader":
				game.unit.spawn.cemitery_add_leader(self)

						
	else: game.test.respawn(self)
