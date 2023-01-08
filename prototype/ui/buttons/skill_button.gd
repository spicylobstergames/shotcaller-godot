extends Button


var skill = null
onready var _name = $name
onready var _cooldown = $cooldown
onready var _game: Node = get_tree().get_current_scene()
var bribe_gold_cost = 10
func _ready():
# warning-ignore:return_value_discarded
	connect("button_down", self, "_button_down")


func setup(_skill):
	self.skill = _skill
	self.disabled = self.skill.on_cooldown()
	_name.text = self.skill.display_name
	self.hint_tooltip = _skill.description

func reset():
	self.icon = null
	self._name.text = ""
	self._cooldown.text = ""
	self.disabled = true
	self.skill = null
	self.hint_tooltip = ""


func _button_down():
	var leader = _game.selected_leader
	if leader.team != _game.player_team:
		return
	if skill.on_cooldown():
		return
	# Apply all skills effects
	for effect in skill.effects:
		var result = effect.call_func(skill.effects, skill.parameters, skill.visualize)
		# wait for skill effect to be done, if it's async
		if result is GDScriptFunctionState:
			result = yield(result, "completed")
			leader.command_casting = false
		# if effect wasn't successful used, then we need to abort using skill
		if !result:
			self.pressed = false
			return
	self.pressed = false
	skill.current_cooldown = skill.cooldown
	leader.command_casting = false


func _physics_process(delta):
	if skill == null:
		return
	if _game.selected_unit.team == null:
		return
	# We shoudln't see enemy skill's cooldowns
	if _game.selected_unit.team != _game.player_team:
		self.disabled = true
		return
	if self.skill.on_cooldown():
		self.disabled = true
		var cooldown_text = str(ceil(self.skill.current_cooldown / 60.0)) + " sec"
		self._cooldown.text = cooldown_text
	else:
		self.disabled = false
		self._cooldown.text = ""
	if skill.display_name == "Bribe" and _game.selected_leader.gold < bribe_gold_cost:
		self.disabled = true
		return
