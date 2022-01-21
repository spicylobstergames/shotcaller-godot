tool
extends Resource
class_name AttrRes

signal change_property(prop_name, prop_value, changed)

var _saved_init_properties = {}


func _init() -> void:
	if not Engine.editor_hint:
		connect("change_property", self, "_on_AttrRes_change_property")


func on_ready() -> void:
	pass


func on_update(attribute: Node, delta: float) -> void:
	pass


func _on_AttrRes_change_property(prop_name: String, prop_value, changed: FuncRef = null) -> void:
	if prop_name in self:
		set(prop_name, prop_value)
		if changed != null:
			changed.call_funcv([prop_name, get(prop_name)])
