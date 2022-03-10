extends YSort

export(Units.TeamID) var team = Units.TeamID.None
export(bool) var mirror_mode = false

var _is_ready: bool = false

var dead_members: Array = []

func _ready() -> void:
	set_physics_process(false)
	_is_ready = true
	for c in get_children():
		c.connect("dead", self, "_on_Leader_dead")


func spawn() -> void:
	_setup_formation()
	_setup_move_leader()
	dead_members = []


func _setup_move_leader():
	var buildings = Units.get_closest_units_by(
		self,
		Units.SortTypeID.Distance,
		Units.get_enemies(self, team, Units.TypeID.Creep, [Units.TypeID.Building], Units.DetectionTypeID.Global)
	)
	buildings.invert()
	if buildings:
		var target_end_point = buildings[0].global_position
		var move_points = Units.get_move_points(self, target_end_point, Units.TypeID.Creep)
		for c in get_children():
			c._setup_spawn()
			c.set("move_points", move_points)
			c.set("target_end_point", target_end_point)
			c.set("allies", get_children())
			c.set("enemies", [])
			c.set("buildings", buildings)

func set_lane(lane: Lane):
	for leader in get_children():
		leader.lane = lane

func _setup_formation() -> void:
	var leader:Node2D = get_children()[0]
	for c in get_children():
		c.set_team(team)
		if mirror_mode:
			c.position.x *= -1.0
			c.get_node("TextureContainer").scale.x = -1


func _on_Leader_dead(unit: PhysicsBody2D) -> void:
	if not unit in dead_members:
		dead_members.append(unit)

	if dead_members.size() == get_children().size():
		Units.available_leader_groups_pools.append(self)

