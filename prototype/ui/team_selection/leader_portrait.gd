extends Sprite


var sprites_order = ["arthur","bokuden","hongi","lorne","nagato","osman","raja","robin","rollo","sida","takoda","tomyris"]
var question_mark = preload("res://assets/ui/question_mark.png")
var leader_icons = preload("res://assets/ui/leaders_icons.png")


func prepare(leader):
	if leader == "random":
		texture = question_mark
		hframes = 1
		frame = 0
	else:
		texture = leader_icons
		var sprite_index = sprites_order.find(leader)
		hframes = sprites_order.size()
		frame = sprite_index
