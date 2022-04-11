extends Node
var game:Node


var _item
var _leader
var _timer

var _leaders_inventories:Node


func _ready():
	game = get_tree().get_current_scene()
	_leaders_inventories = game.ui.leaders_inventories
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.connect("timeout", self, "_timer_timeout")
	add_child(_timer)


func start(item):
	self._item = item
	_timer.start(5)


func _timer_timeout():
	_leaders_inventories.give_item(_leader, _item)
	self._item = null


func is_working():
	return self._item != null

