extends ItemList

onready var _game: Node = get_tree().get_current_scene()
onready var _skill_buttons = $placeholder.get_children()
onready var _tip = $tip

var aura_sprite = preload("res://assets/ui/abilities/aura_of_courage_small.png")

var player_leaders_skills = {}
var enemy_leaders_skills = {}
var _waiting_for_point = false

var visualization = []
enum visualize_type {arc, circle, rectangle, none}
signal point(pos)

class ActiveSkill:
	var display_name
	var description
	var cooldown: int
	var current_cooldown: int
	var visualize
	var parameters: Dictionary # skill parameters: range, angle, color etc...
	var effects: Array # array of skill effects, looks like [FuncRef, FuncRef, ..]
	
	func _init(_display_name, _description, _cooldown, _visualize, _parameters, _effects):
		self.display_name = _display_name
		self.description = _description
		self.cooldown = _cooldown
		self.current_cooldown = 0
		self.visualize = _visualize
		self.parameters = _parameters
		self.effects = _effects
		
	
	func on_cooldown():
		return self.current_cooldown > 0


# Async func to get player point target
func _get_point_target(leader, effects, parameters, visualize):
	self._waiting_for_point = true
	var visualization_node = aoe_vis_setup(leader, effects, parameters, visualize)
	var point = yield(self, "point")
	self._waiting_for_point = false
	aoe_vis_clear(visualization_node)
	return point
# Func to create visualisation if skill using _get_point_target()
func aoe_vis_setup(leader, effects, parameters, visualize):
	var polygon
	match visualize:
		visualize_type.arc:
			polygon =  callv ( "generate_arc_poly", parameters.values())
		visualize_type.circle:
			polygon =  callv ( "generate_circle_poly", parameters.values())
		visualize_type.rectangle:
			polygon =  callv ( "generate_rect_poly", parameters.values())
		visualize_type.none:
			return

	var rotation_node = Node2D.new()
	leader.add_child(rotation_node)
	rotation_node.add_child(polygon)
	visualization.append(rotation_node)
	return rotation_node
#Clearing used nodes
func aoe_vis_clear(visualization_node):
#	for visualization_node in visualization:
	visualization_node.queue_free()
	visualization.erase(visualization_node)

#Circle visualization polygon
func generate_circle_poly(radius: float, num_sides: int, center: Vector2, color: Color) -> PoolVector2Array:
	var angle_delta: float = (PI * 2) / num_sides
	var vector: Vector2 = Vector2(radius, 0)
	var polygon = Polygon2D.new()
	var _points: PoolVector2Array
	
	for point in num_sides:
		_points.append(vector + center)
		vector = vector.rotated(angle_delta)
	polygon.set_polygon(_points)
	polygon.color = color
	
	return polygon
#Arc(cone) visualization polygon
func generate_arc_poly(angle, radius, start_position, finish_position, color: Color):
	var arc_points = 30
	var polygon = Polygon2D.new()
	var _points: PoolVector2Array
	var direction = start_position.direction_to(finish_position) #get normilised direction
	var central_point = direction * radius #get central Vector with radius lenght
	var angle_delta: float = deg2rad(angle) / arc_points #calculating 1 step rotation angle
	var compensate_angle: float = deg2rad(-angle) / 2
	var vector: Vector2 = central_point
	
	vector = vector.rotated(compensate_angle) #rotating to compensate starting point
	_points.append(start_position)
	
	for point in arc_points:
		_points.append(vector + start_position)
		vector = vector.rotated(angle_delta) 
	polygon.set_polygon(_points)
	polygon.color = color
	
	return polygon
#Rectangle visualization polygon
func generate_rect_poly(lenght, width, start_position, finish_position, color: Color):
	
	var polygon = Polygon2D.new()
	var _points: PoolVector2Array
	var direction = start_position.direction_to(finish_position)
	var central_point = direction * lenght
	var left_down = Vector2(direction * width).tangent()
	var right_down = left_down.reflect(direction)
	var left_top = left_down + central_point
	var right_top = right_down + central_point
	
	_points.append(start_position)
	_points.append(left_down)
	_points.append(left_top)
	_points.append(right_top)
	_points.append(right_down)
	
	polygon.set_polygon(_points)
	polygon.color = color

	return polygon
	
func enemies_in_polygon(leader, radius, polygon):
	var targets = []
	for unit in _game.map.blocks.get_units_in_radius(leader.global_position, radius):
		if unit.team != leader.team and Geometry.is_point_in_polygon(unit.global_position, polygon.get_polygon()) and unit.type != "building":
			targets.append(unit)
	return targets

# Example how to write code for point target skill
func robin_special(effects, parameters, visualize):
	var leader = _game.selected_leader
	# Wait for player to click on map to get x and y position
	var point_target = yield(_get_point_target(leader, effects, parameters, visualize), "completed")
	# If player did not clicked then return false, means skill wasn't used and 
	# we didn't want to apply cooldown
	if point_target == null:
		return false
	# do what we need with position
	leader.global_position = point_target
	# return true, means skill was used and we need to apply cooldown
	return true

func rollo_basic():
	var leader = _game.selected_leader
	
	var targets = []
	for unit in _game.map.blocks.get_units_in_radius(leader.global_position, 100):
		if unit.team != leader.team:
			if unit.type == "leader" or unit.type == "pawn":
				targets.append(unit)
	if targets.size() >= 3:
		for unit in targets:
			Behavior.attack.take_hit(leader, unit, null, { "damage": 100 })
	
	return true

func arthur_special(effects, parameters, visualize):
	var leader = _game.selected_leader
	var point_target = yield(_get_point_target(leader, effects, parameters, visualize), "completed")
	if point_target == null:
		return false
	var animations = leader.get_node("animations")
	var skill_animation_sprite = leader.get_node("sprites").get_node("cleave")
	
	var damage_per_hit = [10, 20, 30]
	
	var polygon = generate_arc_poly(parameters.angle, parameters.radius, leader.global_position, point_target, parameters.color)
	var targets = []
	var leader_hit = false
	
	leader.command_casting = true
	for damage in damage_per_hit:
		targets = enemies_in_polygon(leader, parameters.radius, polygon)
		skill_animation_sprite.look_at(point_target)
		skill_animation_sprite.visible = true
		animations.play("arthur_special_cleave")
		yield(animations, "animation_finished")
		skill_animation_sprite.visible = false
		if targets.empty():
			return true
		for unit in targets:
			Behavior.attack.take_hit(leader, unit, null, { "damage": damage * leader.level })
			if unit.type == "leader":
				leader_hit = true
		if leader_hit:
			leader_hit = false
		else: return true
	return true
	
func arthur_active(effects, parameters, visualize):
	var leader = _game.selected_leader
	var point_target = yield(_get_point_target(leader, effects, parameters, visualize), "completed")
	if point_target == null:
		return false
	var polygon = generate_rect_poly(parameters.lenght, parameters.width, leader.global_position, point_target, parameters.color)
	var targets = enemies_in_polygon(leader, parameters.lenght, polygon)
	var damage = 10 * leader.level
	if targets.empty():
		return true
	for unit in targets:
		Behavior.attack.take_hit(leader, unit, null, { "damage": damage })
		unit.start_stun()
	return true

func bokuden_special(effects, parameters, visualize):
	var leader = _game.selected_leader
	var aura_duration = 5
	var speed_modifier = 10
	var range_of_aura = 100
	var targets = []
	var battle_call_timer := Timer.new()

	##timer for aura
	leader.add_child(battle_call_timer)
	battle_call_timer.wait_time = aura_duration
	# warning-ignore:return_value_discarded
	battle_call_timer.connect("timeout", self, "battle_call_remove", [targets])

	for unit in _game.map.blocks.get_units_in_radius(leader.global_position, range_of_aura):
		if unit.team == leader.team and unit.type != "building":
			targets.append(unit)
			battle_call_timer.start()
			Behavior.modifiers.add(unit, "speed", "battle_call", speed_modifier * leader.level)
			unit.status_effects["battle_call"] = {
				icon = aura_sprite,
				hint = "Battle call: Increases speed by %d" % (speed_modifier * leader.level)
			}
	return true
	
func battle_call_remove(_targets):
	for unit in _targets:
		Behavior.modifiers.remove(unit, "speed", "battle_call")
		_targets.erase(unit)
		unit.status_effects.erase("battle_call")

func bokuden_active(effects, parameters, visualize):
	var leader = _game.selected_leader
	var point_target = yield(_get_point_target(leader, effects, parameters, visualize), "completed")
	if point_target == null:
		return false
	var dash_point = leader.global_position.direction_to(point_target)
	dash_point = dash_point * parameters.lenght + leader.global_position
	var dash_tween = Tween.new()
	leader.add_child(dash_tween)
	dash_tween.interpolate_property(leader, "global_position", leader.global_position, dash_point, 0.5, Tween.TRANS_LINEAR)
	leader.look_at(dash_point)
	leader.command_casting = true
	dash_tween.start()
	yield(dash_tween, "tween_completed")
	dash_tween.queue_free()
	return true
	
func osman_special(effects, parameters, visualize):
	var leader = _game.selected_leader
	var bribe_gold_cost = 10
	var effect_duration = 2
	var range_of_effect = 100
	var targets = {}
	
	var bribe_timer := Timer.new()
	leader.add_child(bribe_timer)
	bribe_timer.wait_time = effect_duration * leader.level
	# warning-ignore:return_value_discarded
	bribe_timer.connect("timeout", self, "bribe_remove", [targets])
	if leader.gold < bribe_gold_cost:
		return false
	for unit in _game.map.blocks.get_units_in_radius(leader.global_position, range_of_effect):
		if unit.team != leader.team and unit.type != "leader" and unit.type != "building":
			targets[unit] = unit.team
			unit.setup_team(leader.team)
			Behavior.orders.set_pawn(unit)
			unit.status_effects["Bribed"] = {
				icon = aura_sprite,
				hint = "Bribed: Blinded by greed, defected to the side of the enemy"
			}
	leader.gold -= bribe_gold_cost
	bribe_timer.start()
	return true
	
func bribe_remove(targets):
	for unit in targets.keys():
		if not unit.dead:
			unit.setup_team(targets[unit])
			Behavior.orders.set_pawn(unit)
			targets.erase(unit)
			unit.status_effects.erase("Bribed")
		else: targets.erase(unit)
			
var active_skills = {
	"rollo": [
		ActiveSkill.new(
			"Wolf's teeth",
			"Deals damage in an AOE around it for 100 damage whenever >=3 units are within range",
			120,
			visualize_type.circle,
			{},
			[funcref(self, "rollo_basic")]
		)
	],
	"raja": [
		ActiveSkill.new(
			"Labh, son of Ganesha",
			"Spawn an elephant companion. Can only spawn one elephant at a time", 
			60,
			visualize_type.none,
			{},
			[funcref(self, "raja_basic")]
		)
	],
	"robin": [
		ActiveSkill.new(
			"Call of the forest",
			"Teleport",
			30,
			visualize_type.circle,
			{},
			[funcref(self, "robin_special")]
		)
	],
	"osman": [
		ActiveSkill.new(
			"Bribe",
			"Throw a bag of gold to bribe nearby pawns for 10 sec. Consumes 100 gold", 
			120,
			visualize_type.none,
			{},
			[funcref(self, "osman_special")]
		)
	],
	"takoda": [],
	"arthur": [
		ActiveSkill.new(
			"Cleave",
			"Arthur slashes throw enemies, he can swing three times, but each attack need to hit enemy leader to continue the combination.",
			100,
			visualize_type.arc,
			{"angle": 90, "radius": 50, "center_pos": Vector2(0, 8), "finish_pos": Vector2(300, 0), "color": Color(0,0,100,0.05)},
			[funcref(self, "arthur_special")]
		),
		ActiveSkill.new(
			"Cross-Guard hit",
			"Arthur hits the guard in front of him and stuns the enemy.",
			100,
			visualize_type.rectangle,
			{"lenght": 25, "width": 10, "center_pos": Vector2(0, 8),  "finish_pos": Vector2(300, 0), "color": Color(0,0,100,0.05)},
			[funcref(self, "arthur_active")]
		)
	],
	"bokuden": [
		ActiveSkill.new(
			"Battle Call",
			"The hero leads allies on a furious offensive, increasing their movement speed by by 10 * his level for 5 seconds.",
			600,
			visualize_type.none,
			{},
			[funcref(self, "bokuden_special")]
		),
		ActiveSkill.new(
			"Dash",
			"Bokuden dashes forward and slashes enemies on his way.",
			100,
			visualize_type.rectangle,
			{"lenght": 50, "width": 5, "center_pos": Vector2(0, 8),  "finish_pos": Vector2(300, 0), "color": Color(0,0,100,0.05)},
			[funcref(self, "bokuden_active")]
		),
	],
	"joan": [],
	"lorne": [],
	"sida": [],
	"tomyris": [],
	"nagato": [],
	"hongi": [],
}


func _input(event):
	if self._waiting_for_point:
		if event is InputEventMouseButton:
			if event.pressed:
				if event.button_index == 1:
					emit_signal("point", _game.get_global_mouse_position())
		elif Input.is_action_pressed("ui_cancel"):
			emit_signal("point", null)


func _ready():
	hide()
	clear()


func clear():
	for button in _skill_buttons:
		button.reset()


func update_buttons():
	clear()
	show()
	var leader = _game.selected_leader
	for index in active_skills[leader.display_name].size():
		_skill_buttons[index].setup(active_skills[leader.display_name][index])


func new_skills(leader, skills_storage):
	skills_storage[leader.display_name] = active_skills[leader.display_name].duplicate()


func build_leaders():
	for leader in _game.player_leaders:
		new_skills(leader, player_leaders_skills)
	for leader in _game.enemy_leaders:
		new_skills(leader, enemy_leaders_skills)


func _physics_process(delta):
	_tip.visible = self._waiting_for_point
	
	if self._waiting_for_point == true:
		for polygon in visualization:
			var leader = _game.selected_leader
			var mouse_position =  leader.get_global_mouse_position()
			polygon.look_at(mouse_position)
			
	for skills in player_leaders_skills.values() + enemy_leaders_skills.values():
		for skill in skills:
			skill.current_cooldown = clamp(skill.current_cooldown - 1, 0, skill.current_cooldown)
