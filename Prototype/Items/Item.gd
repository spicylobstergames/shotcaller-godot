class_name Item
extends Reference

enum ItemType { EQUIP, CONSUMABLE }

var sprite
var name
var description
var price
var type
var attributes


func build(name, sprite, description, price, type, attributes):
	self.name = name
	self.sprite = sprite
	self.description = description
	self.price = price
	self.type = type
	self.attributes = attributes
	
	return self
