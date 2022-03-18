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
		Units.filter_enemies(self.get_children()[0].units, self, team, Units.TypeID.Creep, [Units.TypeID.Building], Units.DetectionTypeID.Global)
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
	for creep in get_children():
		creep.lane = lane

func _setup_formation() -> void:
	
	var leader:Node2D = get_children()[0]
	
	for c in get_children():
		c.set_team(team)
		var random_spread = 4.0
		c.position += Vector2(
			rand_range(-random_spread, random_spread),
			rand_range(-random_spread, random_spread))
		if mirror_mode:
			c.position.x *= -1.0
			c.get_node("TextureContainer").scale.x = -1
		c.leader = leader
		c.formation_target = leader.to_local(c.global_position)
	#leader.set_speed_multiplier(0.9)


func _on_Creep_dead(unit: PhysicsBody2D) -> void:
	if not unit in dead_members:
		dead_members.append(unit)

	if dead_members.size() == get_children().size():
		is_available_respawn = true
		Units.available_creep_groups_pools.append(self)

