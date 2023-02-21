extends Sprite


var question_mark = preload("res://assets/ui/question_mark.png")
var leader_icons = preload("res://assets/ui/leaders_icons.png")


func prepare(leader):
	if leader == "random":
		texture = question_mark
		hframes = 1
		frame = 0
	else:
		texture = leader_icons
		var sprite_index = WorldState.leaders[leader]
		hframes = WorldState.leaders.size()
		frame = sprite_index
