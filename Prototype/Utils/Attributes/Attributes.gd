tool
extends Node
class_name Attributes

signal _changed(properties)

export(NodePath) var _unit

export(Resource) var primary = null
export(Resource) var stats = null
export(Resource) var state = null
export(Resource) var radius = null

var unit: Node2D


func _enter_tree() -> void:
	if _unit:
		unit = get_node(_unit)


func _ready() -> void:
	for a in [primary, stats, state, radius]:
		if a != null and a.has_method("on_ready"):
			a.on_ready()


func _physics_process(delta: float) -> void:
	if not Engine.editor_hint:
		stats.on_update(self, delta)
