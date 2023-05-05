extends Button


var skill = null
@onready var _name = $name
@onready var _cooldown = $cooldown
@onready var game: Node = get_tree().get_current_scene()
var bribe_gold_cost = 10


func setup(_skill):
	self.skill = _skill
	self.disabled = self.skill.on_cooldown()
	_name.text = self.skill.display_name
	self.tooltip_text = _skill.description

func reset():
	self.icon = null
	self._name.text = ""
	self._cooldown.text = ""
	self.disabled = true
	self.skill = null
	self.tooltip_text = ""


func _button_down():
	var leader = game.selected_leader
	if leader.team != game.player_team:
		return
	if skill.on_cooldown():
		return
	# Apply all skills effects
	for effect in skill.effects:
		var result = await effect.call_func(skill.effects, skill.parameters, skill.visualize)
		# if effect wasn't successful used, then we need to abort using skill
		if !result:
			self.button_pressed = false
			return
	self.button_pressed = false
	skill.current_cooldown = skill.cooldown


#func _physics_process(delta):
#	if not skill == null:
#		if game.selected_unit and game.selected_unit.team != game.player_team:
#			# We shoudln't see enemy skill's cooldowns
#			self.disabled = true
#		elif self.skill.on_cooldown():
#			self.disabled = true
#			var cooldown_text = str(ceil(self.skill.current_cooldown / 60.0)) + " sec"
#			self._cooldown.text = cooldown_text
#		else:
#			self.disabled = false
#			self._cooldown.text = ""
#		if skill.display_name == "Bribe" and game.selected_leader.gold < bribe_gold_cost:
#			self.disabled = true

