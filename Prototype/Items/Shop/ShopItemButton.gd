extends Control


onready var _item_button = $ItemButton
onready var _name_label = _item_button.get_node("Name")
onready var _price_label = _item_button.get_node("Price")
onready var _shop = get_node("/root/game/ui/Shop")


func setup(item):
	_item_button.setup(item)
	_name_label.text = item.name
	_price_label.text = str(item.price)
	_item_button.connect("button_down", self, "_button_down")


func _button_down():
	_shop.buy(_item_button.item)


func disable():
	_item_button.disabled = true


func enable():
	_item_button.disabled = false


func get_price():
	return _item_button.item.price
