extends Control


onready var _item_button = get_node("item_button")
onready var _name_label = _item_button.get_node("name")
onready var _price_label = _item_button.get_node("price")



var game:Node


func _ready():
	game = get_tree().get_current_scene()



func setup(item):
	_item_button.setup(item)
	_name_label.text = item.name
	_price_label.text = str(item.price)
	_item_button.connect("button_down", self, "_button_down")


func _button_down():
	game.ui.shop.buy(_item_button.item)


func disable():
	_item_button.disabled = true


func enable():
	_item_button.disabled = false


func get_price():
	return _item_button.item.price
