extends YSort

export(Units.TeamID) var team = Units.TeamID.None
export(bool) var mirror_mode = false

var _is_ready: bool = false

var creep_formations = []
var dead_members: Array = []
var is_available_respawn = false

func _ready() -> void:
	set_physics_process(false)
	_is_ready = true
	for c in get_children():
		c.connect("dead", self, "_on_Creep_dead")


func spawn() -> void:
	_setup_formation()
	_setup_move_creep()
	dead_members = []
	is_available_respawn = false


func _setup_move_creep():
	var buildings = Units.get_closest_units_by(
		self,
		Units.SortTypeID.Distance,
		Units.get_enemies(self, team, Units.TypeID.Creep, [Units.TypeID.Building], Units.DetectionTypeID.Global)
	)
	buildings.invert()
	
	if buildings:
		var target_end_point = buildings[0].global_position
		var move_points = Units.get_move_points(self, target_end_point, Units.TypeID.Creep)
		print(move_points)
		for c in get_children():
			c._setup_spawn()
			c.get_node("Blackboard").set_data("move_points", move_points)
			c.get_node("Blackboard").set_data("target_end_point", target_end_point)
			c.get_node("Blackboard").set_data("allies", get_children())
			c.get_node("Blackboard").set_data("enemies", [])
			c.get_node("Blackboard").set_data("buildings", buildings)


func _setup_formation() -> void:
	if creep_formations.empty():
		if mirror_mode:
			var mirror_formations = []
			scale.x = -1
			for c in get_children():
				c.set_team(team)
				mirror_formations.append({
					node = c,
					position = c.global_position
				})
			scale.x = 1
			
			for f in mirror_formations:
				f.node.global_position = f.position
				f.node.get_node("TextureContainer").scale.x = -1

		for c in get_children():
			creep_formations.append({
				node = c,
				position = c.position,
				team = team,
				scale = c.get_node("TextureContainer").scale
			})
	else:
		for f in creep_formations:
			f.node.position = f.position
			f.node.team = f.team
			f.node.get_node("TextureContainer").scale.x = f.scale.x


func _on_Creep_dead(unit: PhysicsBody2D) -> void:
	if not unit in dead_members:
		dead_members.append(unit)

	if dead_members.size() == get_children().size():
		is_available_respawn = true
		Units.available_creep_groups_pools.append(self)

