extends Control


# self = game.ui.active_skills


@onready var game: Node = get_tree().get_current_scene()
@onready var _skill_buttons = $placeholder.get_children()

@onready var _tip = $tip

var aura_sprite = preload("res://assets/ui/abilities/aura_of_courage_small.png")

var player_leaders_skills = {}
var enemy_leaders_skills = {}
var _waiting_for_point = false

var visualization = []
enum visualize_type {arc, circle, rectangle, none}
signal point(pos)

var active_skills = {
	"rollo": {
		"rollo_basic": {
			"display_name": "Wolf's teeth",
			"tooltip": "Deals damage in an AOE around it for 100 damage whenever >=3 units are within range",
			"cooldown": 120,
			"visualize": visualize_type.circle,
			"attributes": {},
			"effects": []
		}
	},
	"raja": {
		"raja_basic": {
			"display_name": "Labh, son of Ganesha",
			"tooltip": "Spawn an elephant companion. Can only spawn one elephant at a time", 
			"cooldown": 60,
			"visualize": visualize_type.none,
			"attributes": {},
			"effects": []
		}
	},
	"robin": {
		"robin_special": {
			"display_name": "Call of the forest",
			"tooltip": "Teleport",
			"cooldown": 30,
			"visualize": visualize_type.circle,
			"attributes": {},
			"effects": []
		}
	},
	"osman": {
		"osman_special": {
			"display_name": "Bribe",
			"tooltip": "Throw a bag of gold to bribe nearby pawns for 10 sec. Consumes 100 gold", 
			"cooldown": 120,
			"visualize": visualize_type.none,
			"attributes": {},
			"effects": []
		}
	},
	"takoda": {},
	"arthur": {
		"arthur_active": {
			"display_name": "Guard Break",
			"tooltip": "Arthur hits the guard in front of him and stuns the enemy.",
			"cooldown": 100,
			"visualize": visualize_type.rectangle,
			"attributes": {"length": 25, "width": 10, "center_pos": Vector2(0, 8), "finish_pos": Vector2(300, 0), "color": Color(0,0,100,0.05)},
			"effects": []
		},
		"arthur_special": {
			"display_name": "Cleave",
			"tooltip": "Arthur slashes throw enemies, he can swing three times, but each attack need to hit enemy leader to continue the combination.",
			"cooldown": 100,
			"visualize": visualize_type.arc,
			"attributes": {"angle": 90, "radius": 50, "center_pos": Vector2(0, 8), "finish_pos": Vector2(300, 0), "color": Color(0,0,100,0.05)},
			"effects": []
		}
	},
	"bokuden": {
		"bokuden_special": {
			"display_name": "Battle Call",
			"tooltip": "The hero leads allies on a furious offensive, increasing their movement speed by by 10 * his level for 5 seconds.",
			"cooldown": 600,
			"visualize": visualize_type.none,
			"attributes": {},
			"effects": []
		},
		"bokuden_active": {
			"display_name": "Dash",
			"tooltip": "Bokuden dashes forward and slashes enemies on his way.",
			"cooldown": 100,
			"visualize": visualize_type.rectangle,
			"attributes": {"length": 50, "width": 5, "center_pos": Vector2(0, 8), "finish_pos": Vector2(300, 0), "color": Color(0,0,100,0.05)},
			"effects": []
		}
	},
	"joan": {},
	"lorne": {},
	"sida": {},
	"tomyris": {},
	"nagato": {},
	"hongi": {}
}


class ActiveSkill:
	var display_name
	var description
	var cooldown: int
	var current_cooldown: int
	var visualize
	var parameters: Dictionary # skill parameters: range, angle, color etc...
	var effects: Array # array of skill effects
	
	func _init(_display_name,_description,_cooldown,_visualize,_parameters,_effects):
		self.display_name = _display_name
		self.description = _description
		self.cooldown = _cooldown
		self.current_cooldown = 0
		self.visualize = _visualize
		self.parameters = _parameters
		self.effects = _effects
		
	
	func on_cooldown():
		return self.current_cooldown > 0


# callback func to get player point target
func _get_point_target(leader, effects, parameters, visualize):
	self._waiting_for_point = true
	var visualization_node = aoe_vis_setup(leader, effects, parameters, visualize)
	var point_target = await self.point
	self._waiting_for_point = false
	aoe_vis_clear(visualization_node)
	return point_target


# Func to create visualisation if skill using _get_point_target()
func aoe_vis_setup(leader, _effects, parameters, visualize):
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


# clearing used nodes
func aoe_vis_clear(visualization_node):
#	for visualization_node in visualization:
	visualization_node.queue_free()
	visualization.erase(visualization_node)


# circle visualization polygon
func generate_circle_poly(radius: float, num_sides: int, center: Vector2, color: Color) -> PackedVector2Array:
	var angle_delta: float = (PI * 2) / num_sides
	var vector: Vector2 = Vector2(radius, 0)
	var polygon = Polygon2D.new()
	var _points: PackedVector2Array = []
	
	for _point in num_sides:
		_points.append(vector + center)
		vector = vector.rotated(angle_delta)
	polygon.set_polygon(_points)
	polygon.color = color
	
	return polygon


# arc(cone) visualization polygon
func generate_arc_poly(angle, radius, start_position, finish_position, color: Color):
	var arc_points = 30
	var polygon = Polygon2D.new()
	var _points: PackedVector2Array = []
	var direction = start_position.direction_to(finish_position) #get normilised direction
	var central_point = direction * radius #get central Vector with radius length
	var angle_delta: float = deg_to_rad(angle) / arc_points #calculating 1 step rotation angle
	var compensate_angle: float = deg_to_rad(-angle) / 2
	var vector: Vector2 = central_point
	
	vector = vector.rotated(compensate_angle) #rotating to compensate starting point
	_points.append(start_position)
	
	for _point in arc_points:
		_points.append(vector + start_position)
		vector = vector.rotated(angle_delta) 
	polygon.set_polygon(_points)
	polygon.color = color
	
	return polygon


# rectangle visualization polygon
func generate_rect_poly(length, width, start_position, finish_position, color: Color):
	
	var polygon = Polygon2D.new()
	var _points: PackedVector2Array = []
	var direction = start_position.direction_to(finish_position)
	var central_point = direction * length
	var left_down = Vector2(direction * width).orthogonal()
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
	for unit in leader.get_units_in_radius(radius, { "team": leader.team }):
		if unit.type != "building"and Geometry2D.is_point_in_polygon(unit.global_position, polygon.get_polygon()):
			targets.append(unit)
	return targets


# Example how to write code for point target skill
func robin_special(effects, parameters, visualize):
	var leader = WorldState.get_state("selected_leader")
	# Wait for player to click on map to get x and y position
	var point_target = await _get_point_target(leader, effects, parameters, visualize)
	
	# If player did not clicked then return false, means skill wasn't used and 
	# we didn't want to apply cooldown
	if point_target == null:
		return false
	# do what we need with position
	leader.global_position = point_target
	# return true, means skill was used and we need to apply cooldown
	return true


func rollo_basic():
	var leader = WorldState.get_state("selected_leader")
	var range_of_effect = 100
	var damage = 100
	
	var targets = []
	for unit in leader.get_units_in_radius(range_of_effect, { "team": leader.opponent_team() }):
		if unit.type != "building":
			targets.append(unit)
	if targets.size() >= 3:
		for unit in targets:
			Behavior.attack.take_hit(leader, unit, null, { "damage": damage })
	
	return true


func arthur_special(effects, parameters, visualize):
	var leader = WorldState.get_state("selected_leader")
	var point_target = await _get_point_target(leader, effects, parameters, visualize)
	if point_target != null:
		var animations = leader.get_node("animations")
		var skill_animation_sprite = leader.get_node("sprites/cleave")
		var polygon = generate_arc_poly(parameters.angle, parameters.radius, leader.global_position, point_target, parameters.color)
		var targets = enemies_in_polygon(leader, parameters.radius, polygon)
		skill_animation_sprite.look_at(point_target)
		skill_animation_sprite.show()
		animations.play("arthur_special_cleave")
		# damage targets
		if not targets.is_empty():
			for unit in targets:
				var damage = 100 * leader.level
				Behavior.attack.take_hit(leader, unit, null, { "damage": damage })



func arthur_special_end():
	var leader = null
	var skill_animation_sprite = leader.get_node("sprites/cleave")
	skill_animation_sprite.hide()



func arthur_active(effects, parameters, visualize):
	var leader = WorldState.get_state("selected_leader")
	var point_target = await _get_point_target(leader, effects, parameters, visualize)
	if point_target == null:
		return false
	var polygon = generate_rect_poly(parameters.length, parameters.width, leader.global_position, point_target, parameters.color)
	var targets = enemies_in_polygon(leader, parameters.length, polygon)
	var damage = 10 * leader.level
	if targets.is_empty():
		return true
	for unit in targets:
		Behavior.attack.take_hit(leader, unit, null, { "damage": damage })
		unit.start_stun()
	return true


func bokuden_special(_effects, _parameters, _visualize):
	var leader = WorldState.get_state("selected_leader")
	var aura_duration = 5
	var speed_modifier = 10
	var range_of_aura = 100
	var targets = []
	var battle_call_timer := Timer.new()

	##timer for aura
	leader.add_child(battle_call_timer)
	battle_call_timer.wait_time = aura_duration
	# warning-ignore:return_value_discarded
	battle_call_timer.timeout.connect(battle_call_remove.bind(targets))

	for unit in leader.get_units_in_radius(range_of_aura, {"team": leader.team}):
		if unit.type != "building":
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
	var leader = WorldState.get_state("selected_leader")
	var point_target = await _get_point_target(leader, effects, parameters, visualize)
	if point_target:
		var dash_point = leader.global_position.direction_to(point_target)
		dash_point = dash_point * parameters.length + leader.global_position
		var dash_tween = Tween.new()
		leader.add_child(dash_tween)
		dash_tween.interpolate_property(leader, "global_position", leader.global_position, dash_point, 0.5, Tween.TRANS_LINEAR)
		leader.mirror_look_at(dash_point)
		dash_tween.start()
		await dash_tween.finished
		dash_tween.queue_free()


func osman_special(_effects, _parameters, _visualize):
	var leader = WorldState.get_state("selected_leader")
	var bribe_gold_cost = 10
	var effect_duration = 2
	var range_of_effect = 100
	var targets = {}
	
	var bribe_timer := Timer.new()
	leader.add_child(bribe_timer)
	bribe_timer.wait_time = effect_duration * leader.level
	# warning-ignore:return_value_discarded
	bribe_timer.timeout.connect(bribe_remove.bind(targets))
	if leader.gold >= bribe_gold_cost:
		for unit in leader.get_units_in_radius(range_of_effect, { "team": leader.opponent_team(), "type": "pawn" }):
			targets[unit] = unit.team
			unit.setup_team(leader.team)
			Behavior.orders.set_pawn(unit)
			unit.status_effects["Bribed"] = {
				icon = aura_sprite,
				hint = "Bribed: Blinded by greed, defected to the side of the enemy"
			}
		leader.gold -= bribe_gold_cost
		bribe_timer.start()


func bribe_remove(targets):
	for unit in targets.keys():
		if not unit.dead:
			unit.setup_team(targets[unit])
			Behavior.orders.set_pawn(unit)
			targets.erase(unit)
			unit.status_effects.erase("Bribed")
		else: targets.erase(unit)


func _ready():
	hide()
	#clear()


func reset_buttons():
	for button in _skill_buttons:
		button.reset()


func update_buttons():
	reset_buttons()
	show()
	var leader = WorldState.get_state("selected_leader")
	if leader.name in player_leaders_skills:
		var player_skills = player_leaders_skills[leader.name].values()
		for index in _skill_buttons.size():
			_skill_buttons[index].setup(player_skills[index])


func new_skills(leader, skills_storage):
	var leader_skills = active_skills[leader.display_name]
	for skill_name in leader_skills:
		var skill = leader_skills[skill_name]
		
		var display_name = skill.display_name
		var tooltip = skill.tooltip
		var cooldown = skill.cooldown
		var visualize = skill.visualize
		var attributes = skill.attributes
		var effects = skill.effects
		
		if !leader.name in skills_storage: skills_storage[leader.name] = {}
		
		skills_storage[leader.name][display_name] = ActiveSkill.new(display_name, tooltip, cooldown, visualize, attributes, effects)


func build_leaders():
	for leader in WorldState.get_state("player_leaders"):
		new_skills(leader, player_leaders_skills)
	for leader in WorldState.get_state("enemy_leaders"):
		new_skills(leader, enemy_leaders_skills)

func input(event):
	if (self._waiting_for_point and 
		event is InputEventMouseButton and 
		event.is_pressed() and 
		event.button_index == 1):
			
			emit_signal("point", Crafty_camera.get_global_mouse_position())
			
	elif Input.is_action_pressed("ui_cancel"):
		self._waiting_for_point = false


func process(_delta):
	_tip.visible = self._waiting_for_point
	
	if self._waiting_for_point:
		for polygon in visualization:
			var mouse_position =  Crafty_camera.get_global_mouse_position()
			polygon.look_at(mouse_position)


func count_down(skills):
	for leader_name in skills:
		var leader = skills[leader_name]
		for skill_name in leader:
			var skill = leader[skill_name]
			skill.current_cooldown = clamp(skill.current_cooldown - 1, 0, skill.current_cooldown)


func one_sec_cycle():
	count_down(player_leaders_skills)
	count_down(enemy_leaders_skills)
