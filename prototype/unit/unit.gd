extends Node
class_name Unit
var game:Node

# self = game.unit

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
var units_in_radius := []
var agent = GoapAgent.new()

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
export var attack_range:float = 1
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
var sprites:Node
var body:Node

# Experience
var get_units_timer : Timer = Timer.new()
var experience_timer : Timer = Timer.new()
var experience : float = 0
var level : int = 1

const EXP_RANGE = 200
const EXP_PER_KILL = 20
const EXP_PER_5_SEC = 5
const EXP_LEVEL_COEFFICIENT = 100

# SCORE
var last_attacker : Unit = null
var last_hit_count = 0
var kills = 0
var deaths = 0
var assists = 0
# Key - unit, value - OS.get_ticks_msec() - time when attack was performed
var assist_candidates = {}
# Maximum time between a units last attack on a target and its death for it to
# count as an assist
const ASSIST_TIME_IN_SECONDS = 3

var status_effects = {}


func _ready():
	game = get_tree().get_current_scene()

	if has_node("hud"): hud = get_node("hud")

	if has_node("sprites"): sprites = get_node("sprites")
	if has_node("sprites/body"): body = get_node("sprites/body")
	if has_node("sprites/weapon"): weapon = get_node("sprites/weapon")
	if has_node("sprites/weapon/projectile"): projectile = get_node("sprites/weapon/projectile")
	current_modifiers = Behavior.modifiers.new_modifiers()

	if type != "pawn":
		# save units around for items and exp
		get_units_timer.wait_time = 1
		get_units_timer.autostart = true
# warning-ignore:return_value_discarded
		get_units_timer.connect("timeout", self, "on_every_second")
		add_child(get_units_timer)

		experience_timer.wait_time = 5
		experience_timer.autostart = true
# warning-ignore:return_value_discarded
		experience_timer.connect("timeout", self, "on_experience_tick")
		add_child(experience_timer)
	if find_node("goals"):
		var goals = []
		for goal in find_node("goals").goals:
			goals.push_back(GoapGoals.get_goal(goal))
		agent.init(self, goals)
		add_child(agent)

func gain_experience(value):
	experience += value
	if experience >= experience_needed():
		experience -= experience_needed()
		level += 1

func on_experience_tick():
	gain_experience(EXP_PER_5_SEC)
	experience_timer.start()

func experience_needed():
	return EXP_LEVEL_COEFFICIENT * level

func reset_unit():
	self.setup_team(self.team)

	if self.type == "leader":
		Hud.state.visible = true
		Hud.hpbar.visible = true

	Hud.state.text = self.display_name
	self.current_hp = self.hp
	self.current_modifiers = Behavior.modifiers.new_modifiers()
	self.visible = true
	self.stunned = false
	self.hunting = false
	self.channeling = false
	self.retreating = false
	self.working = false
	Hud.update_hpbar(self)
	game.ui.minimap.setup_symbol(self)
	assist_candidates = {}
	last_attacker = null

func set_state(s):
	if not self.dead:
		self.state = s
		self.get_node("animations").current_animation = s


func set_behavior(s):
	self.behavior = s
	#self.get_node("hud/state").text = s


func setup_team(new_team):
	self.team = new_team

	# fog setup
	if game.map.fog_of_war and self.has_node("light"):
		var light = get_node("light")
		light.visible = false
		if new_team == game.player_team: light.visible = true
		var s = self.vision / 16
		light.scale = Vector2(s,s)
		sprites.use_parent_material = true

	# color body sprite
	set_anim(new_team, body)

	# color weapons
	if weapon is AnimatedSprite: set_anim(new_team, weapon)
	if has_node("sprites/weapon/spear"):
		var spear = get_node("sprites/weapon/spear")
		set_anim(new_team, spear)
		var spear_proj = get_node("sprites/weapon/projectile/sprites")
		set_anim(new_team, spear_proj)

	# mirror red pawns, leaders and neutrals
	var is_red = (self.team == "red")
	if self.type != "building": self.mirror_toggle(is_red)

	else: # mirror lumbermill
		if self.display_name == "lumbermill" and self.get_parent().name == "blue":
			self.mirror_toggle(true)

		# color flags
		var flags = self.get_node("sprites/flags").get_children()
		for flag in flags:
			var flag_sprite = flag.get_node("sprites")
			set_anim(new_team, flag_sprite)


func set_anim(new_team, sprite):
	if new_team and sprite:
		match new_team:
			"blue": sprite.animation = 'default'
			"red": sprite.animation = 'red'
			"neutral": sprite.animation = 'neutral'


func oponent_team():
	match self.team:
		"red": return "blue"
		"blue": return "red"
		"neutral": return "all"


func look_at(point):
	if self.type != "building":
		self.mirror_toggle(point.x - self.global_position.x < 0)


func mirror_toggle(on):
	self.mirror = on
	var s = -1 if on else 1
	self.get_node("sprites").scale.x = s
	if self.attack_hit_position:
		self.attack_hit_position.x = s * abs(self.attack_hit_position.x)


func sort_by_distance(array):
	var sorted = []
	for unit2 in array:
		sorted.append({
			"unit": unit2,
			"distance": self.global_position.distance_to(unit2.global_position)
		})
	sorted.sort_custom(game.utils, "compare_distance")
	return sorted


func closest_unit(enemies):
	var sorted = self.sort_by_distance(enemies)
	return sorted[0].unit


func cut_path(path):
	var distances = []
	var path_size = path.size()
	var first_point = path[0]
	for index in path_size:
		var point = path[index]
		var d1 = self.global_position.distance_to(point)
		var d2 = first_point.distance_to(point)
		distances.append({
			"distance": d1 - (d2 / 10),
			"point": point,
			"index": index
		})
	distances.sort_custom(game.utils, "compare_distance")
	var next_first_point = distances[0]
	
	var new_path = path.slice(next_first_point.index, path_size)
	return new_path


func point_collision(point, offset=0):
	var unit1_pos = self.global_position + self.collision_position
	return game.utils.circle_point_collision(point, unit1_pos, self.collision_radius + offset)


func check_collision(unit2, delta):
	var unit1_pos = self.global_position + self.collision_position + (self.current_step * delta)
	var unit1_rad = self.collision_radius
	var unit2_pos = unit2.global_position + unit2.collision_position + (unit2.current_step * delta)
	var unit2_rad = unit2.collision_radius
	return game.utils.circle_collision(unit1_pos, unit1_rad, unit2_pos, unit2_rad)


func get_collision_around(delta):
	var unit1_pos = self.global_position + self.collision_position + (self.current_step * delta)
	var unit1_rad = self.collision_radius
	return game.map.blocks.get_units_in_radius(unit1_pos, unit1_rad)


func get_units_on_sight(filters):
	var current_vision = Behavior.modifiers.get_value(self, "vision")
	var pos1 = self.global_position
	var neighbors = game.map.blocks.get_units_in_radius(pos1, current_vision)
	var targets = []
	for unit2 in neighbors:
		if unit2.hp and self != unit2 and not unit2.dead and not unit2.immune:
			if not filters: targets.append(unit2)
			else:
				for filter in filters:
					if unit2[filter] == filters[filter]:
						targets.append(unit2)
	return targets


func get_enemy_leaders_on_sight(unit):
	var targets = []
	var leaders_on_sight = unit.get_units_on_sight({"type": "leader"})
	for leader in leaders_on_sight:
		if leader.team != unit.team:
			targets.append(leader)
			
	return targets
	
	
func on_every_second():
	self.units_in_radius = game.map.blocks.get_units_in_radius(self.global_position, EXP_RANGE);
	for i in units_in_radius:
		if i.team != "neutral" and i.type != "building" and i.team != self.team  and agent != null and type == "worker":
			agent.set_state("is_threatened", true)
			break

func wait():
	self.wait_time = game.rng.randi_range(1,4)
	self.set_state("idle")


func on_idle_end(): # every idle animation end (0.6s)
	Behavior.advance.on_idle_end(self)
	if self.wait_time > 0: self.wait_time -= 1
	else: game.test.unit_wait_end(self)


func on_move(delta): # every frame if there's no collision
	Behavior.move.step(self, delta)


func on_collision(delta):
	if self.moves:
		Behavior.move.on_collision(self, delta)
		if self.attacks:
			Behavior.advance.on_collision(self)


func on_move_end(): # every move animation end (0.6s for speed = 1)
	if self.moves and self.attacks: Behavior.advance.resume(self)
	if self == game.selected_unit: Behavior.follow.draw_path(self)



func on_arrive(): # when collides with destiny
	if self.current_path.size() > 0:
		Behavior.follow.next(self)
	elif self.moves:
		self.working = false
		Behavior.move.end(self)

		if self.attacks: Behavior.advance.end(self)
		if agent != null: 
			agent.on_arrive()
		
		match self.after_arive:
			"conquer": Behavior.orders.conquer_building(self)
			"pray": Behavior.orders.pray_in_church(self)
			"lumber_arive": Behavior.orders.lumber_arive(self)


func on_attack_release(): # every ranged projectile start
	Behavior.attack.projectile_release(self)
	Behavior.advance.resume(self)


func on_attack_hit():  # every melee attack animation end (0.6s for ats = 1)
	if self.attacks:
		Behavior.attack.hit(self)
		if self.moves:
			Behavior.advance.resume(self)


func heal(heal_hp):
	self.current_hp += heal_hp
	self.current_hp = int(min(self.current_hp, Behavior.modifiers.get_value(self, "hp")))
	Hud.update_hpbar(self)
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
			Behavior.move.resume(self)
		if self.behavior == "advance":
			Behavior.advance.resume(self)
		if self.behavior == "stand" or self.behavior == "stop":
			self.set_state("idle")



func die():  # hp <= 0
	self.set_state("death")
	self.set_behavior("stand")
	self.dead = true
	self.target = null
	self.channeling = false
	self.working = false

	var neighbors = self.units_in_radius
	for neighbor in neighbors:
		if neighbor.type == "leader" and neighbor.team != team:
			neighbor.gain_experience(EXP_PER_KILL)

	if type == 'leader':
		if last_attacker:
			last_attacker.kills += 1
		deaths += 1
		for attacker in assist_candidates.keys():
			if attacker == last_attacker:
				continue
			if OS.get_ticks_msec() - assist_candidates[attacker] < ASSIST_TIME_IN_SECONDS * 1000:
					attacker.assists += 1
	elif type == 'pawn' and last_attacker != null:
		last_attacker.last_hit_count += 1


func on_death_end():  # death animation end
	self.global_position = Vector2(-1000, -1000)
	self.visible = false
	self.state = 'dead'
	self.get_node("animations").current_animation = "[stop]"
	Behavior.attack.clear_stuck(self)
	if game.test.stress: game.test.respawn(self)
	else:
		match self.type:
			"pawn": Behavior.spawn.cemitery_add_pawn(self)
			"leader": Behavior.spawn.cemitery_add_leader(self)
			"building":
				if self.display_name == 'castle':
					EventMachine.register_event(Events.GAME_END,
							["ENEMY" if team == game.player_team else "PLAYER"])

