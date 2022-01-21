tool
extends AttrRes
class_name AttrResState

export(Units.BehaviorStateID) var behavior = Units.BehaviorStateID.None
export(Units.ActionStateID) var action = Units.ActionStateID.None
export(Units.ReactionStateID) var reaction = Units.ReactionStateID.None


func on_ready() -> void:
	_saved_init_properties["behavior"] = behavior
	_saved_init_properties["action"] = action
	_saved_init_properties["reaction"] = reaction
