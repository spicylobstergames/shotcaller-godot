extends Node


func start(unit, destiny):
	if (unit.moves):
		unit.current_destiny = destiny
		calc_step(unit)
		unit.set_state("move")


func calc_step(unit):
	if unit.current_speed > 0:
		var distance = unit.current_destiny - unit.global_position
		unit.angle = distance.angle()
		unit.current_step = Vector2(unit.current_speed * cos(unit.angle), unit.current_speed * sin(unit.angle))
		unit.look_at(unit.current_destiny)


func step(unit):
	unit.global_position += unit.current_step


func end(unit):
	unit.current_step = Vector2.ZERO
	unit.current_destiny = Vector2.ZERO
	unit.set_state("idle")
