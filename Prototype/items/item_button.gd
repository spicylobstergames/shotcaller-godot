 extends Button

var item = null


func setup(new_item):
	if new_item == null:
		self.item = null
		self.name = "Item Slot"
		self.icon = null
		self.hint_tooltip = "Buy items in the Blacksmith"
		self.disabled = true
		return
	
	self.item = new_item
	self.name = new_item.name

	var icon = new_item.icon
	if not new_item.icon:
		icon = self.icon.duplicate()
		icon.region.position.x = 8 + new_item.sprite * 60
		icon.region.position.y = 6
		new_item.icon = icon
		
	self.icon = icon
	
	self.hint_tooltip = new_item.description
