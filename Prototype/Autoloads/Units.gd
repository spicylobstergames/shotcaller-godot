extends Node

enum TeamID {None, Neutral, Blue, Red}
enum TypeID {None, Leader, Creep, Building, Enviroment}
enum BehaviorStateID {None, Idle, Farming, Jungling, Pushing, Teleport, BackToBase, Trapped, DefendTower}
enum ReactionStateID {None, Normal, Targeted}
enum ActionStateID {None, AttackLeader, AttackCreep, AttackBuilding}
enum SortTypeID {Distance, Health}
enum DetectionTypeID {Area, Global}
enum StatusEffectID {Stun, Root, Silence, Slow}

var selected_units: Array = []

var _navmap: Navigation2D = null

var arena_teams = {TeamID.Blue: null, TeamID.Red: null}

var creep_group_max_pool_count: Array = [2,2,2,2]
var creep_group_pool_count: Array = [0,0,0,0]

var available_creep_groups_pools: Array = []

onready var CreepGroupClass = load("res://Character/Child/Creep/CreepGroup.tscn")

func _ready() -> void:
	_setup_navigation()
	arena_teams = _get_arena_teams()


func spawn_one(team: int, new_units, parent_node: Node2D, spawn_position: Vector2) -> Node2D:
	new_units.team = team
	new_units.mirror_mode = Units.arena_teams[team].mirror_mode
	for c in new_units.get_children():
		c.team = team
		if new_units.mirror_mode:
			c.position.x *= -1.0
			c.get_node("TextureContainer").scale.x = -1
	parent_node.add_child(new_units)
	new_units.global_position = spawn_position
	return new_units


func try_spawn_creep_wave(parent_node: Node2D) -> void:
	get_tree().call_group("creep_spawner", "spawn_creep_wave", parent_node)

func get_closest_units_by(node: Node2D, sort_type: int, units: Array) -> Array:
	var data_units = []
	var sorted_units = []
	
	for u in units:
		data_units.append({
			node = u,
			distance = node.global_position.distance_to(u.global_position),
			health = u.attributes.stats.health
		})
		
	match sort_type:
		SortTypeID.Distance:
			data_units.sort_custom(self, "_sort_by_distance")
		SortTypeID.Health:
			data_units.sort_custom(self, "_sort_by_health")
	
	for u in data_units:
		sorted_units.append(u.node)

	return sorted_units

#func get_closest_units(node: PhysicsBody2D, teams: Array = [], types: Array = []) -> Array:
#	var units: Array = []
#
#	if not node.has_node("UnitDetector"):
#		return units
#
#
#	for u in node.get_node("UnitDetector").get_overlapping_areas():
#		if u.get_node("Stats") == null:
#			break
#
#		if u.owner != node and u.stats.team in teams and u.stats.unit_type in types:
#			units.append(u.owner)
#
#	return units


#func get_avoid_objects(node: PhysicsBody2D) -> Array:
#	var objects: Array = []
#
#	if not node.has_node("UnitDetector"):
#		return objects
#
#	for o in node.get_node("UnitDetector").get_overlapping_bodies():
#		if o.get_node("Stats") == null:
#			break
#
#		if o != node and node.global_position.distance_to(o.global_position) < node.stats.unit_detection_range:
#			objects.append(o)
#
#	return objects


# Handle Movable Unit
func get_move_points(node: Node2D, target_position: Vector2, type: int = TypeID.Leader) -> PoolVector2Array:
	var navmap = get_navmap()
	var move_points = []
	if navmap: move_points = navmap.get_simple_path(node.global_position, target_position, true)
	return move_points
	
	
func get_move(units: Array, target_position: Vector2, type: int = TypeID.Leader, formation: bool = false) -> void:
	if formation:
		var target_positions: Array = _get_position_list_arround(target_position, units)
		var target_position_idx: int = 0
		for u in units:
			move_one(u, target_positions[target_position_idx], type)
			target_position_idx = (target_position_idx + 1) % target_positions.size()
	else:
		for u in units:
			move_one(u, target_position, type)


func move_one(unit: PhysicsBody2D, target_position: Vector2, type: int = TypeID.Leader) -> void:
	var navmap = get_navmap()
	var move_points = navmap.get_simple_path(unit.global_position, target_position, true)
	if not move_points.empty():
		unit.move_position = move_points[move_points.size() - 1]
		unit.move_points = move_points

func get_all_allies(current_team: int) -> Array:
	var output = []
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.attributes.primary.unit_team == current_team:
			output.append(unit)
	return output

func filter_allies(units: Array, node: Node2D, current_team: int, current_type: int, target_types: PoolIntArray = [], detection_type: int = DetectionTypeID.Area, radius: float = 1000) -> Array:
	var allies: Array = []
	match current_team:
		TeamID.Neutral:
			match current_type:
				TypeID.Creep:
					allies = _filter_all(units, node, [TeamID.Neutral], [TypeID.Creep], radius)
		TeamID.Blue:
			match current_type:
				TypeID.Creep, TypeID.Leader, TypeID.Building:
					allies = _filter_all(units, node, [TeamID.Blue], [TypeID.Leader, TypeID.Creep, TypeID.Building], radius)
		TeamID.Red:
			match current_type:
				TypeID.Creep, TypeID.Leader, TypeID.Building:
					allies = _filter_all(units, node, [TeamID.Red], [TypeID.Leader, TypeID.Creep, TypeID.Building], radius)
	
	var filtered_allies = []
	if not target_types.empty():
		for i in range(allies.size()):
			if allies[i].attributes.primary.unit_type in target_types:
				filtered_allies.append(allies[i])
		return filtered_allies
				
	return allies
	

func filter_enemies(units:Array, node: Node2D, current_team: int, current_type: int, target_types: PoolIntArray = [], detection_type: int = DetectionTypeID.Area, radius: float = 1000) -> Array:
	var enemies: Array = []

	match current_team:
		TeamID.Neutral:
			match current_type:
				TypeID.Creep:
					enemies = _filter_all(units, node, [TeamID.Blue, TeamID.Red], [TypeID.Leader], radius)
		TeamID.Blue:
			match current_type:
				TypeID.Creep:
					enemies = _filter_all(units, node, [TeamID.Red], [TypeID.Leader, TypeID.Creep, TypeID.Building], radius)
				TypeID.Leader:
					enemies = _filter_all(units, node, [TeamID.Neutral, TeamID.Red], [TypeID.Leader, TypeID.Creep, TypeID.Building], radius)
				TypeID.Building:
					enemies = _filter_all(units, node, [TeamID.Red], [TypeID.Leader, TypeID.Creep], radius)
		TeamID.Red:
			match current_type:
				TypeID.Creep:
					enemies = _filter_all(units, node, [TeamID.Blue], [TypeID.Leader, TypeID.Creep, TypeID.Building], radius)
				TypeID.Leader:
					enemies = _filter_all(units, node, [TeamID.Neutral, TeamID.Blue], [TypeID.Leader, TypeID.Creep, TypeID.Building], radius)
				TypeID.Building:
					enemies = _filter_all(units, node, [TeamID.Blue], [TypeID.Leader, TypeID.Creep], radius)
	
	var filtered_enemies = []
	if not target_types.empty():
		for i in range(enemies.size()):
			if enemies[i].attributes.primary.unit_type in target_types:
				filtered_enemies.append(enemies[i])
		return filtered_enemies

	return enemies

func _filter_all(units: Array, node: Node2D, target_teams: PoolIntArray, target_types: PoolIntArray, radius: float = 1000) -> Array:
	var filtered_units: Array = []
	
	for u in units:
		if u.attributes.primary.unit_team in target_teams and u.attributes.primary.unit_type in target_types:
			if node.global_position.distance_to(u.global_position) < radius:
				filtered_units.append(u)

	return filtered_units

func get_all(node: Node2D, detection_type: int = DetectionTypeID.Area) -> Array:
	var units: Array = []
	
	match detection_type:
		DetectionTypeID.Area:
			if node.has_node("UnitDetector"):
				units = node.get_node("UnitDetector").get_overlapping_bodies()
		DetectionTypeID.Global:
			units = get_tree().get_nodes_in_group("units")
	
	return units

func _get_position_list_arround(target_position: Vector2, units: Array) -> PoolVector2Array:
	var positions: PoolVector2Array = PoolVector2Array()
	
	for i in range(units.size()):
		var distance = 0
		if units.size() > 1:
			distance = units[i].get("stats").distance_between_units
		var angle = i * (360.0 / units.size())
		var dir = (Vector2(1, 0).rotated(deg2rad(angle)))
		positions.append(target_position + (dir * distance))
	
	return positions


func _get_arena_teams() -> Dictionary:
	var new_arena_teams: Dictionary = {}
	for t in get_tree().get_nodes_in_group("arena_team"):
		new_arena_teams[t.team] = t
	return new_arena_teams


func get_navmap() -> Navigation2D:
	return _navmap


func _setup_navigation() -> void:
	_navmap = get_tree().get_nodes_in_group("navigation")[0]


func _sort_by_health(a: Dictionary, b: Dictionary) -> bool:
	if a.health < b.health:
		return true
	return false


func _sort_by_distance(a: Dictionary, b: Dictionary) -> bool:
	if a.distance < b.distance:
		return true
	return false
