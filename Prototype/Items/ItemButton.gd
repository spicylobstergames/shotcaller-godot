extends Button

var item = null


func setup(new_item):
	if new_item == null:
		self.item = null
		self.name = "item name"
		self.icon = null
		self.hint_tooltip = "hint tooltip"
		self.disabled = true
		return
	
	self.item = new_item
	self.name = new_item.name
	self.icon = new_item.sprite
	self.hint_tooltip = new_item.description
