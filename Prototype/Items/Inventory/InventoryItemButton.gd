extends Control

var index = 0

onready var _sell_button = $SellButton
onready var _item_button = $ItemButton


func _ready():
	_sell_button.hide()
	
	_sell_button.connect("button_down", self, "_sell_button_down")
	_item_button.connect("button_down", self, "_item_button_down")


func setup(item):
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
	var leader = Leaders.selected_leader
	print('ibd')
	for key in _item_button.item.attributes.keys():
		leader.attributes.stats[key] += _item_button.item.attributes[key]
	
	get_tree().get_current_scene().get_node("GUI/BotRightContainer/LeadersInventories").remove_item(leader, index)


func _sell_button_down():
	get_tree().get_current_scene().get_node("GUI/TopRightContainer/Shop/ShopWindow").sell(index)
