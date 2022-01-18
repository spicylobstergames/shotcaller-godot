extends "res://Utils/BasicAttackArea.gd"



func _physics_process(delta: float) -> void:
	if target:
		look_at(target.get_node("HitArea").global_position)


func release() -> void:
	if not target.is_dead:
		rotation_degrees = 0
		$Tween.follow_property(self, "global_position", global_position, target.get_node("HitArea"), "global_position", 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN)
		$Tween.interpolate_property(self, "modulate:a", modulate.a, 0.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN)
		$Tween.start()
		yield($Tween, "tween_all_completed")
		visible = false
		queue_free()
