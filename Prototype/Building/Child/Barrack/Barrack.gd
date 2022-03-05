extends "res://Building/Building.gd"

const FlagClass := preload("res://Building/Node/Flag.gd")

var CreepGroupClass = preload("res://Character/Child/Creep/CreepGroup.tscn")
var creep_spawn_positon = Vector2(0,0)

func _setup_team() -> void:
	for t in $TextureContainer/Sprite.get_children():
		if t is FlagClass:
			t.set_team(team)
	if team == Units.TeamID.Red:
		var inverted_points = PoolVector2Array([]) + lane.points
		inverted_points.invert()
		creep_spawn_positon = inverted_points[0]
	else:
		creep_spawn_positon = lane.points[0]
	._setup_team()

func spawn_creep_wave(parent_node: Node2D):
	var new_creep_group: YSort = null
	new_creep_group = Units.spawn_one(team, CreepGroupClass, parent_node, creep_spawn_positon)
	new_creep_group.set_lane(lane)
	if new_creep_group:
		new_creep_group.mirror_mode = Units.arena_teams[team].mirror_mode
		new_creep_group.spawn()
