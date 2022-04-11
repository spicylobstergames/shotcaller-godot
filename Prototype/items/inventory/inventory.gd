extends HBoxContainer
var game:Node

const EQUIP_ITEMS_MAX = 2
const CONSUMABLE_ITEMS_MAX = 1

var leader
var equip_items = []
var consumable_items = []
var _equip_item_buttons = []
var _consumable_item_buttons = []

var gold = 0
var _gold_timer


func _ready():
	game = get_tree().get_current_scene()
	
	_gold_timer = Timer.new()
	add_child(_gold_timer)
	_gold_timer.connect("timeout", self, "_gold_timer_timeout")
	_gold_timer.start(1)
	
# warning-ignore:unused_variable
	for index in range(EQUIP_ITEMS_MAX):
		equip_items.append(null)
# warning-ignore:unused_variable
	for index in range(CONSUMABLE_ITEMS_MAX):
		consumable_items.append(null)


func _gold_timer_timeout():
		# Updating gold label
	gold += 1
	_gold_timer.start(1)
	if game.selected_leader: game.ui.stats.update()
	game.ui.shop_window.update_buttons()


func add_item(new_item):
	if new_item.type == new_item.ItemType.EQUIP:
		for index in range(EQUIP_ITEMS_MAX):
			if equip_items[index] == null:
				equip_items[index] = new_item
				return
	elif new_item.type == new_item.ItemType.CONSUMABLE:
		for index in range(CONSUMABLE_ITEMS_MAX):
			if consumable_items[index] == null:
				consumable_items[index] = new_item
				return


func is_equip_items_has_slots():
	for item in equip_items:
		if item == null:
			return true
	return false


func is_consumable_items_has_slots():
	for item in consumable_items:
		if item == null:
			return true
	return false

