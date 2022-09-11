extends Sprite

var sprites_order = ["arthur","bokuden","hongi","lorne","nagato","osman","raja","robin","rollo","sida","takoda","tomyris"]

func prepare(leader):
	var sprite_index = sprites_order.find(leader)
	region_rect.position.x = sprite_index * 96
