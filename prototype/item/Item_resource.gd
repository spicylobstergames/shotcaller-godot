extends Resource

class_name Item_resource

@export var name:String = "Item Name"
@export var tooltip:String = "Item description\nDamage +10"
@export var attributes:Dictionary = {"damage": 10}
@export var type:String = "equip"
@export var delivery_time:int = 30
@export var sprite:int = 0
@export var price:int = 10
@export var passive:String = ""
@export var ready:bool = false
@export var delivered:bool = false
@export var sell_price:int = 5
