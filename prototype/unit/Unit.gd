extends Node2D

class_name Unit

var game:Node

# self = game.unit

# SIGNALS
signal unit_reseted
signal unit_idle_ended
signal unit_move_ended
signal unit_arrived
signal unit_started_channeling
signal unit_healed
signal unit_leveled_up
signal unit_attack_release # ranged projectile
signal unit_attack_hitted # melee hit
signal unit_attack_ended
signal unit_was_attacked(attacker: Unit, damage: int)
signal unit_stuned
signal unit_stun_ended
signal unit_animation_ended
signal unit_death_started
signal unit_died

@export var hp:int = 100
var current_hp:int = 100
@export var regen:int = 0
@export var vision:int = 100
@export var type:String = "pawn" # building leader
@export var subtype:String = "melee" # ranged base lane backwood
@export var display_name:String
@export var title:String
@export var team:String = "blue"
@export var respawn:float = 1
var dead:bool = false
@export var immune:bool = false
var mirror:bool = false
var texture:Dictionary
var units_in_radius := []
var symbol:bool = false
var current_modifiers = Goap.modifiers.new_modifiers()

# SELECTION
@export var selectable:bool = false
var selection_radius = 36
var selection_position:Vector2 = Vector2.ZERO

# MOVEMENT
@export var moves:bool = false
@export var mounted:bool = false
@export var speed:float = 0
@export var hunting_speed:float = 0
var angle:float = 0
var current_step:Vector2 = Vector2.ZERO
var current_destiny:Vector2 = Vector2.ZERO
var final_destiny:Vector2 = Vector2.ZERO
var current_path:Array = []

# COLLISION
@export var collide:bool = false
var collision_radius = 0
var collision_position:Vector2 = Vector2.ZERO

# ATTACK
@export var attacks:bool = false
@export var ranged:bool = false
@export var damage:int = 0
@export var attack_range:float = 1
@export var attack_speed:float = 1
@export var defense:int = 0
var target:Node2D
var last_target:Node2D
var aim_point:Vector2
var attack_count = 0
var weapon:Node2D

# PROJECTILES
var projectile:Node2D # template
var projectiles:Array = []
@export var projectile_speed:float = 3
@export var projectile_rotation:float = 0
var attack_hit_position:Vector2 = Vector2.ONE
var attack_hit_radius = 24

# BEHAVIOR
var next_event:String = "" # "move" or "arrive"
var after_arive:String = "stop" # "attack" "conquer" "pray" "cut"
var state:String = "idle" # "move", "attack", "death"
var priority = ["leader", "pawn", "building"]
var tactics:String = "default" # aggresive defensive retreat
var wait_time:int = 0
var gold = 0

# ORDERS
var control_delay = 3
var curr_control_delay = 0
var channeling_timer:Timer

# NODES
var hud:Node
var sprites:Node
var body:Node
@onready var agent: Node = get_node_or_null("goap_agent")
var navigation_agent: NavigationAgent2D
var navigation_safe_velocity := Vector2.ZERO
var has_navigation_safe_velocity := false

# Experience
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
# Key - unit, value - Time.get_ticks_msec() - time when attack was performed
var assist_candidates = {}
# Maximum time between a units last attack on a target and its death for it to
# count as an assist
const ASSIST_TIME_IN_SECONDS = 3

var status_effects = {}


func _ready():
	game = get_tree().get_current_scene()

	hud = get_node_or_null("hud")
	sprites = get_node_or_null("sprites")
	body = get_node_or_null("sprites/body")
	weapon = get_node_or_null("sprites/weapon")
	projectile = get_node_or_null("sprites/weapon/projectile")
	if moves:
		ensure_navigation_agent()


func ensure_navigation_agent() -> NavigationAgent2D:
	if navigation_agent == null:
		navigation_agent = NavigationAgent2D.new()
		navigation_agent.name = "NavigationAgent2D"
		navigation_agent.path_desired_distance = 12.0
		navigation_agent.target_desired_distance = 8.0
		navigation_agent.avoidance_enabled = true
		navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)
		add_child(navigation_agent)
	return navigation_agent


func set_navigation_target(target_vector: Vector2) -> void:
	if navigation_agent == null:
		ensure_navigation_agent()
	if navigation_agent:
		has_navigation_safe_velocity = false
		navigation_safe_velocity = Vector2.ZERO
		navigation_agent.target_position = target_vector


func advance_with_navigation(_delta: float) -> bool:
	if navigation_agent == null or navigation_agent.target_position == Vector2.ZERO:
		return false
	if navigation_agent.is_target_reached():
		return false
	var next_point = navigation_agent.get_next_path_position()
	var direction = next_point - global_position
	if direction.length_squared() <= 0.01:
		return false
	var current_speed = Goap.modifiers.get_value(self, "speed")
	var desired_velocity = direction.normalized() * current_speed
	navigation_agent.velocity = desired_velocity
	current_step = navigation_safe_velocity if has_navigation_safe_velocity else desired_velocity
	mirror_look_at(next_point)
	return true


func _on_navigation_velocity_computed(safe_velocity: Vector2) -> void:
	navigation_safe_velocity = safe_velocity
	has_navigation_safe_velocity = true


func setup_leader_exp():
		experience_timer.wait_time = 5
		experience_timer.autostart = true
		experience_timer.timeout.connect(on_experience_tick)
		add_child(experience_timer)


func gain_experience(value):
	experience += value
	if experience >= experience_needed():
		experience -= experience_needed()
		level += 1
		emit_signal("unit_leveled_up")

func on_experience_tick():
	gain_experience(EXP_PER_5_SEC)
	experience_timer.start()

func experience_needed():
	return EXP_LEVEL_COEFFICIENT * level


func reset_unit():
	var lane = self.agent.get_state("lane")
	if self.type == "leader":
		self.hud.state.show()
		self.hud.hpbar.show()

	self.hud.state.text = Utils.first_to_uppper(self.display_name)
	self.current_hp = self.hp
	self.current_modifiers = Goap.modifiers.new_modifiers()
	self.show()
	self.hud.update_hpbar()
	game.ui.minimap.setup_symbol(self)
	self.assist_candidates = {}
	self.last_attacker = null
	
	emit_signal("unit_reseted")
	
	
	self.agent.set_state("lane", lane)
	self.setup_team(self.team)
	


func set_state(s):
	if not self.dead:
		self.state = s
		var animations = get_node_or_null("animations")
		if animations:
			animations.current_animation = s


func setup_team(new_team):
	self.team = new_team
	var map = WorldState.get_state("map")
	if map and map.fog_of_war:
		var light = get_node_or_null("light")
		if light:
			light.hide()
			if new_team == WorldState.get_state("player_team"): light.show()
			var s = self.vision / 16
			light.scale = Vector2(s,s)
	
	if sprites:
		sprites.use_parent_material = true

	set_anim(new_team, body)

	if weapon is AnimatedSprite2D: set_anim(new_team, weapon)
	var spear = get_node_or_null("sprites/weapon/spear")
	if spear:
		set_anim(new_team, spear)
		var spear_proj = get_node_or_null("sprites/weapon/projectile/sprites")
		if spear_proj:
			set_anim(new_team, spear_proj)

	var is_red = (self.team == "red")
	if self.type != "building": self.mirror_toggle(is_red)
	else:
		if self.display_name == "lumbermill" and self.get_parent().name == "blue":
			self.mirror_toggle(true)

		var flags = get_node_or_null("sprites/flags")
		if flags:
			for flag in flags.get_children():
				var flag_sprite = flag.get_node_or_null("sprites")
				if flag_sprite:
					set_anim(new_team, flag_sprite)


func set_anim(new_team, sprite):
	if new_team and sprite:
		match new_team:
			"blue": sprite.animation = "default"
			"red": sprite.animation = "red"
			"neutral": sprite.animation = "neutral"


func opponent_team():
	match self.team:
		"red": return "blue"
		"blue": return "red"
		"neutral": return "all"


func mirror_look_at(point: Vector2):
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
	sorted.sort_custom(Utils.compare_distance)
	return sorted


func closest_unit(enemies):
	var sorted = self.sort_by_distance(enemies)
	return sorted[0].unit

func is_controllable():
	return game.can_control(self)

func start_control_delay():
	self.curr_control_delay = self.control_delay


func set_delay():
	if self.curr_control_delay > 0:
		self.curr_control_delay -= 1


func cut_path(path):
	var distances = []
	var path_size = path.size()
	if path_size > 0:
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
		distances.sort_custom(Utils.compare_distance)
		var next_first_point = distances[0]
	
		var new_path = path.slice(next_first_point.index, path_size)
		return new_path
	return path


func point_collision(point, offset=0):
	var unit1_pos = self.global_position + self.collision_position
	return Utils.circle_point_collision(point, unit1_pos, self.collision_radius + offset)


func get_units_in_radius(radius, filters = {}, pos = self.global_position):
	var neighbors = Collisions.get_units_in_radius(pos, radius)
	var targets = []
	for unit2 in neighbors:
		if self != unit2 and not unit2.dead:
			if filters.size() == 0: targets.append(unit2)
			else:
				for filter in filters:
					if unit2[filter] == filters[filter]:
						targets.append(unit2)
	return targets


func get_units_in_sight(filters = {}):
	var current_vision = Goap.modifiers.get_value(self, "vision")
	return self.get_units_in_radius(current_vision, filters)


func get_units_in_attack_range(filters = {}):
	var current_range = Goap.modifiers.get_value(self, "attack_range")
	var pos = self.global_position + self.attack_hit_position
	return self.get_units_in_radius(current_range, filters, pos)


func gold_timer_timeout():
	game.ui.inventories.gold_timer_timeout(self)


func wait():
	self.wait_time = game.rng.randi_range(1,4)
	self.set_state("idle")


func on_idle_end(): # every idle animation end (0.6s)
	emit_signal("unit_idle_ended")
	emit_signal("unit_animation_ended")


func on_move(delta): # movement tick
	Goap.move.step(self, delta)


func on_move_end(): # every move animation end (0.6s for speed = 1)
	if self.moves: emit_signal("unit_move_ended")
	emit_signal("unit_animation_ended")


func on_arrive(): # when collides with destiny
	emit_signal("unit_arrived")


func on_attack_release(): # every ranged projectile start
	if self.attacks:
		Goap.attack.projectile_release(self)
		emit_signal("unit_attack_release")


func on_attack_hit():  # every melee attack animation end (0.6s for ats = 1)
	if self.attacks:
		Goap.attack.hit(self)
		emit_signal("unit_attack_hitted")


func was_attacked(attacker, _damage):
	unit_was_attacked.emit(attacker, _damage)


func on_attack_end(): # animation end of all attacks
	if self.attacks: emit_signal("unit_attack_ended")
	emit_signal("unit_animation_ended")


func heal(heal_hp):
	self.current_hp += heal_hp
	self.current_hp = int(min(self.current_hp, Goap.modifiers.get_value(self, "hp")))
	self.hud.update_hpbar()
	emit_signal("unit_healed")


func channel_start(time):
	self.agent.set_state("is_channeling" , true)
	self.agent.set_state("has_player_command", true)
	if self.channeling_timer.time_left > 0:
		self.channeling_timer.stop()
	self.channeling_timer.wait_time = time
	self.channeling_timer.start()
	emit_signal("unit_started_channeling")


func stun_start():
	self.wait_time = 2
	self.agent.set_state("is_stunned", true)
	self.agent.set_state("stunned", true)
	self.agent.set_state("is_channeling", false)
	if self.agent.get_state("player_order", {}).get("type", "") == "teleport":
		self.agent.set_state("player_order_id", self.agent.get_state("player_order_id", 0) + 1)
	self.set_state("stun")
	emit_signal("unit_stuned")


func on_stun_end():
	if self.wait_time > 1: self.wait_time -= 1
	else:
		self.agent.set_state("is_stunned", false)
		self.agent.set_state("stunned", false)
		emit_signal("unit_stun_ended")
		emit_signal("unit_animation_ended")


func die():  # hp <= 0
	self.set_state("death")
	self.dead = true
	self.target = null
	
	self.agent.set_state("is_channeling", false)
	Goap.get_action("OrderAction").cancel_player_order(self.agent)

	var neighbors = self.units_in_radius
	for neighbor in neighbors:
		if neighbor.type == "leader" and neighbor.team != team:
			neighbor.gain_experience(EXP_PER_KILL)

	if type == "leader":
		if last_attacker:
			last_attacker.kills += 1
		deaths += 1
		for attacker in assist_candidates.keys():
			var in_time = Time.get_ticks_msec() - assist_candidates[attacker] < ASSIST_TIME_IN_SECONDS * 1000
			if attacker != last_attacker and in_time:
				attacker.assists += 1
	elif type == "pawn" and last_attacker != null:
		last_attacker.last_hit_count += 1
	
	emit_signal("unit_death_started")


func hide_in_map():
	self.global_position = Vector2(-1000, -1000)
	self.hide()
	self.state = "dead"
	var animations = get_node_or_null("animations")
	if animations:
		animations.current_animation = "[stop]"


func on_death_end():  # death animation end
	self.hide_in_map()
	
	Goap.attack.clear_stuck(self)
	
	if game.test.debug and game.test.stress: game.test.respawn(self)
	else:
		match self.type:
			"worker": game.spawn.cemitery_add_worker(self)
			"pawn": game.spawn.cemitery_add_pawn(self)
			"leader": game.spawn.cemitery_add_leader(self)
			"building":
				if self.display_name == "castle":
					game.end(team == WorldState.get_state("enemy_team"))
			
	
	emit_signal("unit_died")
