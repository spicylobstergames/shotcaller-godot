extends Control
var game:Node


var index = 0

onready var _sell_button = get_node("sell_button")
onready var _item_button = get_node("item_button")


func _ready():
	game = get_tree().get_current_scene()
	
	_sell_button.hide()
	
	_sell_button.connect("button_down", self, "_sell_button_down")
	_sell_button.get_node("item_touch_button").connect("button_down", self, "_sell_button_down")
	_item_button.connect("button_down", self, "_item_button_down")
	_item_button.get_node("item_touch_button").connect("button_down", self, "_item_button_down")


func setup(item):
	game = get_tree().get_current_scene()
	_item_button.setup(item)
	if item != null:
		if item.type == item.ItemType.CONSUMABLE:
			_item_button.disabled = false


func set_item_type_to_equip():
	_item_button.disabled = true


func show_sell_button():
	if _item_button.item != null:
		_sell_button.show()
	else:
		_sell_button.hide()


func hide_sell_button():
	_sell_button.hide()


func _item_button_down():
	var leader = game.selected_leader
	
	for key in _item_button.item.attributes.keys():
		leader.attributes.stats[key] += _item_button.item.attributes[key]
	
	game.ui.leaders_inventories.remove_item(leader, index)


func _sell_button_down():
	game.ui.shop.sell(index)
