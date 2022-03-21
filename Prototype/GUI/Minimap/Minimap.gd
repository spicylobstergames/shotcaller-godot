extends Node2D

var _numbers:Array = []

func _ready():
	Leaders.connect("leaders_spawned", self, "_on_start")


func _on_start() -> void:
	for i in range(5):
		var leader = Leaders.current_leaders[i]
		var number = Label.new()
		number.text = str(i)
		number.set_global_position(leader.global_position/20)
		$ViewportContainer/Viewport.add_child(number)
		_numbers.append(number)

func _process(delta):
	if Leaders.current_leaders.size() > 0 and _numbers.size() > 0:
		for i in range(5):
			var leader = Leaders.current_leaders[i]
			var number = _numbers[i]
			if is_instance_valid(leader):
				number.set_global_position(leader.global_position/20)
			else: number.hide()
