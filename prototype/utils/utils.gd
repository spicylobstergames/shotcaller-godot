extends Node
var game:Node

# self = game.utils

func _ready():
	game = get_tree().get_current_scene()


func circle_point_collision(p, c, r):
	return p.distance_to(c) < r


func circle_collision(c1, r1, c2, r2):
	return c1.distance_to(c2) < (r1 + r2)


func sort_by_hp(array):
	var sorted = []
	for neighbor in array:
		sorted.append({
			"unit": neighbor,
			"hp": neighbor.current_hp
		})
	sorted.sort_custom(self, "compare_hp")
	return sorted


func compare_hp(a: Dictionary, b: Dictionary) -> bool:
	return a.hp < b.hp


func compare_distance(a: Dictionary, b: Dictionary) -> bool:
	return a.distance < b.distance


func closer_lane(point):
	var distances = []
	for lane in WorldState.lanes:
		for lane_point in lane:
			distances.append({
				"distance": point.distance_to(lane_point),
				"lane": lane
			})
	distances.sort_custom(self, "compare_distance")
	return distances[0].lane


func closer_building(point, team):
	var distances = []
	var buildings = game.player_buildings
	if team != game.player_team: buildings = game.enemy_buildings
	for building in buildings:
		distances.append({
			"distance": point.distance_to(building.global_position),
			"building": building
		})
	distances.sort_custom(self, "compare_distance")
	return distances[0].building


func limit_angle(a):
	if (a > PI): a -= PI*2
	if (a < -PI): a += PI*2
	return a


func random_point():
	var o = 50
	return Vector2(o+randf()*(game.map.size-o*2), o+randf()*(game.map.size-o*2))


func offset_point_random(point, offset):
	var x = (-offset) + (randf()*offset*2)
	var y = (-offset) + (randf()*offset*2)
	var p = point + Vector2(x, y)
	return p


var font
func label(string):
	var label_node = Label.new()
	label_node.text = string
	if not font:
		font = game.ui.shop.get_node("scroll_container/container/equip").get_font("font")
	label_node.add_font_override("font", font)
	return label_node


func get_building(point):
	for building in game.player_buildings:
		if click_distance(building, point): return building
	for building in game.enemy_buildings:
		if click_distance(building, point): return building
	for building in game.neutral_buildings:
		if click_distance(building, point): return building
	return null


func click_distance(unit, point):
	return unit.global_position.distance_to(point) <= unit.selection_radius
