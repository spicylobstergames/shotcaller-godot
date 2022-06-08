extends Node
var game:Node

# self = game.unit.orders

export var hp:int = 100
var current_hp:int = 100
export var regen:int = 0
export var vision:int = 100
var current_modifiers = {}
export var type:String = "pawn" # building leader
export var subtype:String = "melee" # ranged base lane backwood
export var display_name:String
export var title:String
export var team:String = "blue"
export var respawn:float = 1
var dead:bool = false
export var immune:bool = false
var mirror:bool = false
var texture:Dictionary

# SELECTION
export var selectable:bool = false
var selection_radius = 36
var selection_position:Vector2 = Vector2.ZERO

# MOVEMENT
export var moves:bool = false
export var mounted:bool = false
export var speed:float = 0
export var hunting_speed:float = 0
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
var collision_timer:Timer

# ATTACK
export var attacks:bool = false
export var ranged:bool = false
var stunned:bool = false
export var damage:int = 0
export var attack_range:int = 1
export var attack_speed:float = 1
export var defense:int = 0
var target:Node2D
var last_target:Node2D
var aim_point:Vector2
var attack_count = 0
var weapon:Node2D

# PROJECTILES
var projectile:Node2D # template
var projectiles:Array = []
export var projectile_speed:float = 3
export var projectile_rotation:float = 0
var attack_hit_position:Vector2 = Vector2.ONE
var attack_hit_radius = 24

# BEHAVIOR
export var lane:String = "mid"
var next_event:String = "" # "on_arive" "on_move" "on_collision"
var after_arive:String = "stop" # "attack" "conquer" "pray" "cut"
var behavior:String = "stand" # "move", "attack", "advance", "stop"
var state:String = "idle" # "move", "attack", "death"
var priority = ["leader", "pawn", "building"]
var tactics:String = "default" # aggresive defensive retreat 
var objective:Vector2 = Vector2.ZERO
var wait_time:int = 0
var gold = 0

# ORDERS
var retreating = false
var working = false
var hunting = false
var channeling = false
var channeling_timer:Timer

# NODES
var hud:Node
var spawn:Node
var move:Node
var attack:Node
var advance:Node
var follow:Node
var orders:Node
var skills:Node
var modifiers:Node

func _ready():
	game = get_tree().get_current_scene()
	
	if has_node("hud"): hud = get_node("hud")
	if has_node("behavior/spawn"): spawn = get_node("behavior/spawn")
	if has_node("behavior/move"): move = get_node("behavior/move")
	if has_node("behavior/attack"): attack = get_node("behavior/attack")
	if has_node("behavior/advance"): advance = get_node("behavior/advance")
	if has_node("behavior/follow"): follow = get_node("behavior/follow")
	if has_node("behavior/orders"): orders = get_node("behavior/orders")
	if has_node("behavior/skills"): skills = get_node("behavior/skills")
	if has_node("behavior/modifiers"): modifiers = get_node("behavior/modifiers")
	
	if has_node("sprites/weapon"): weapon = get_node("sprites/weapon")
	if has_node("sprites/weapon/projectile"): projectile = get_node("sprites/weapon/projectile")



func reset_unit():
	self.setup_team(self.team)
	
	if self.type == "leader": 
		self.hud.state.visible = true
		self.hud.hpbar.visible = true
	
	self.hud.state.text = self.display_name
	self.current_hp = self.hp
	self.current_modifiers = modifiers.new_modifiers()
	self.visible = true
	self.stunned = false
	self.hunting = false
	self.channeling = false
	self.retreating = false
	self.working = false
	self.hud.update_hpbar(self)
	game.ui.minimap.setup_symbol(self)


func set_state(s):
	if not self.dead:
		self.state = s
		self.get_node("animations").current_animation = s


func set_behavior(s):
	self.behavior = s
	#self.get_node("hud/state").text = s


func setup_team(team):
	self.team = team
	
	var is_red = (self.team == "red")
	var is_blue = (self.team == "blue")
	var is_neutral = (self.team == "neutral")
	# UPDATE TEXTURE COLORS
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
	else: 
		# mirror lumbermill
		if self.display_name == "lumbermill" and get_parent().name == "blue":
			self.mirror_toggle(true)
		# color flags
		var flags = self.get_node("sprites/flags").get_children()
		for flag in flags:
			var flag_sprite = flag.get_node("sprite")
			var material = flag_sprite.material.duplicate()
			var color = 1
			if is_blue: color = 0
			if is_neutral: color = 2
			material.set_shader_param("change_color", color)
			flag_sprite.material = material
		
			

func oponent_team():
	var t = "blue"
	if self.team == t: t = "red"
	return t


func look_at(point):
	if self.type != "building":
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
			if self.mounted: scale = Vector2(1.8,1.8)
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
	var current_vision = game.unit.modifiers.get_value(self, "vision")
	var neighbors = game.map.blocks.get_units_in_radius(self.global_position, current_vision)
	var targets = []
	for unit2 in neighbors:
		if unit2.hp and self != unit2 and not unit2.dead and not unit2.immune:
			var distance = self.global_position.distance_to(unit2.global_position)
			if distance < current_vision:
				if not filters: targets.append(unit2)
				else:
					for filter in filters:
						if unit2[filter] == filters[filter]:
							targets.append(unit2)
	return targets



func wait():
	self.wait_time = game.rng.randi_range(1,4)
	self.set_state("idle")


func on_idle_end(): # every idle animation end (0.6s)
	game.unit.advance.on_idle_end(self)
	if self.wait_time > 0: self.wait_time -= 1
	else: game.test.unit_wait_end(self)


func on_move(delta): # every frame if there's no collision
	game.unit.move.step(self, delta)


func on_collision(delta):
	if self.moves: 
		game.unit.move.on_collision(self, delta)
		if self.attacks: 
			game.unit.advance.on_collision(self)


func on_move_end(): # every move animation end (0.6s for speed = 1)
	if self.moves and self.attacks: game.unit.advance.resume(self)
	if self == game.selected_unit: game.unit.follow.draw_path(self)



func on_arrive(): # when collides with destiny
	if self.current_path.size() > 0:
		game.unit.follow.next(self)
	elif self.moves:
		self.working = false
		game.unit.move.end(self)
		
		if self.attacks: game.unit.advance.end(self)
		
		match self.after_arive:
			"conquer": game.unit.orders.conquer_building(self)
			"pray": game.unit.orders.pray_in_church(self)
			"cut": game.unit.orders.lumber_cut(self)
			"lumber_arive": game.unit.orders.lumber_arive(self)


func on_attack_release(): # every ranged projectile start
	game.unit.attack.projectile_release(self)
	game.unit.advance.resume(self)


func on_attack_hit():  # every melee attack animation end (0.6s for ats = 1)
	if self.attacks: 
		game.unit.attack.hit(self)
		if self.moves:
			game.unit.advance.resume(self)


func heal(heal_hp):
	self.current_hp += heal_hp
	self.current_hp = int(min(self.current_hp, game.unit.modifiers.get_value(self, "hp")))
	game.unit.hud.update_hpbar(self)
	if self == game.selected_unit: game.ui.stats.update()


func channel_start(time):
	self.channeling = true
	self.working = true
	if self.channeling_timer.time_left > 0: 
		self.channeling_timer.stop()
	self.channeling_timer.wait_time = time
	self.channeling_timer.start()


func stun_start():
	self.wait_time = 2
	self.stunned = true
	self.channeling = false
	self.set_state("stun")


func on_stun_end():
	if self.wait_time > 1: self.wait_time -= 1
	else:
		self.stunned = false
		if self.behavior == "move":
			game.unit.move.resume(self)
		if self.behavior == "advance":
			game.unit.advance.resume(self)
		if self.behavior == "stand" or self.behavior == "stop":
			self.set_state("idle")


func die():  # hp <= 0
	self.set_state("death")
	self.set_behavior("stand")
	self.dead = true
	self.target = null
	self.channeling = false
	self.working = false


func on_death_end():  # death animation end
	self.global_position = Vector2(-1000, -1000)
	self.visible = false
	self.state = 'dead'
	self.get_node("animations").current_animation = "[stop]"
	if not game.test.stress:
		match self.type:
			"pawn":
				game.unit.spawn.cemitery_add_pawn(self)
			"leader":
				game.unit.spawn.cemitery_add_leader(self)
	
	else: game.test.respawn(self)
