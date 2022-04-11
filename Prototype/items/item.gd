class_name Item
extends Reference

enum ItemType { EQUIP, CONSUMABLE }

var icon
var sprite
var name
var description
var price
var type
var attributes


func build(_name, _sprite, _description, _price, _type, _attributes):
	self.name = _name
	self.sprite = _sprite
	self.description = _description
	self.price = _price
	self.type = _type
	self.attributes = _attributes
	
	return self
