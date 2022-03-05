extends Node

var _item
var _leader
var _timer

onready var _leaders_inventory = get_node("../LeadersInventory")


func _ready():
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.connect("timeout", self, "_timer_timeout")
	add_child(_timer)


func start(item):
	self._item = item
	_timer.start(5)


func _timer_timeout():
	_leaders_inventory.add_item(_leader.name, _item)
	self._item = null


func is_working():
	return self._item != null

