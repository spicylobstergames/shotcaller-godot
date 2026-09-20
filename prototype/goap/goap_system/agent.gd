extends Node

# self = Goap.Agent
# This script integrates the unit (NPC) with GOAP.
# In your implementation you could have this logic
# inside your NPC script.
#
# As good practice, I suggest leaving it isolated like
# this, so it makes re-use easy and it doesn't get tied
# to unrelated implementation details (movement, collisions, etc).

@export var goals_list: Array = []

var debug_agent := false

var _goals: Array
var _current_goal
var _current_plan
var _current_plan_step := 0
var _unit
var _state: Dictionary = {}

var attacked_timer := 2


func _ready():
	_goals = []
	if goals_list.size() > 0:
		for goal in goals_list:
			_goals.append(Goap.get_goal(goal))

	_unit = get_parent()

	_unit.unit_reseted.connect(reset)
	_unit.unit_collided.connect(on_collision)
	_unit.unit_arrived.connect(on_arrive)
	_unit.unit_idle_ended.connect(on_idle_end)
	_unit.unit_stun_ended.connect(on_stun_end)
	_unit.unit_move_ended.connect(on_move_end)
	_unit.unit_attack_ended.connect(on_attack_end)
	_unit.unit_animation_ended.connect(on_animation_end)
	_unit.unit_was_attacked.connect(was_attacked)

	WorldState.one_sec_timer.timeout.connect(on_every_second)


func get_unit():
	return _unit


func get_state(state_name, default = null):
	if _state.has(state_name):
		return _state[state_name]
	return default


func set_state(state_name, value):
	_state[state_name] = value


func clear_state():
	_state.clear()


func reset():
	clear_state()
	_current_goal = null
	_current_plan = null


func get_current_action():
	if (_current_plan != null and _current_plan.size() > 0):
		return _current_plan[_current_plan_step]
	else:
		return null


func has_action_function(func_name):
	var action = get_current_action()
	return action != null and action.has_method(func_name)


func has_goal_function(func_name):
	var goal = _get_best_goal()
	return goal != null and goal.has_method(func_name)



# On every loop this script checks if the current goal is still
# the highest priority. if it's not, it requests the action planner a new plan
# for the new high priority goal.
func process(delta):
	var goal = _get_best_goal()
	if _current_goal == null or goal != _current_goal:
		if _current_plan and _current_plan_step < _current_plan.size():
			_current_plan[_current_plan_step].exit(self)
		_current_goal = goal
		_current_plan = []
		_current_plan_step = 0
		if _current_goal:
			_current_plan = Goap.get_action_planner().get_plan(self, _current_goal)
			if _current_plan.size() > 0:
				_current_plan[0].enter(self)
	else:
		_follow_plan(_current_plan, delta)


# Returns the highest priority goal available.
func _get_best_goal():
	var highest_priority
	for goal in _goals:
		if goal.is_valid(self) and (highest_priority == null or goal.priority(self) > highest_priority.priority(self)):
			highest_priority = goal
	
	return highest_priority


# Executes plan. This function is called on every game loop.
# "plan" is the current list of actions, and delta is the time since last loop.
#
# Every action exposes a function called perform, which will return true when
# the job is complete, so the agent can jump to the next action in the list.
func _follow_plan(plan, delta):
	if plan.size() > 0:
		var is_step_complete = plan[_current_plan_step].perform(self, delta)
		
		# debug
		if debug_agent: 
			#_unit.hud.state.text = get_current_action().get_class_name()
			_unit.hud.state.text = _get_best_goal().get_class_name()
		
		if is_step_complete:
			get_current_action().exit(self) #untested
			if _current_plan_step < plan.size() - 1:
				_current_plan_step += 1
				get_current_action().enter(self)
			else:
				#trigger replan
				_current_goal = null
				_current_plan = null


func on_every_second() :
	var is_regenerating_unit = _unit.type != "building" or _unit.team == "neutral"
	if _unit.regen > 0 and is_regenerating_unit:
		if not _unit.dead:
			_unit.heal(Goap.modifiers.get_value(_unit, "regen"))
		else:
			_unit.regen = 0
	if not _unit.dead:
		var dot_effects = Goap.modifiers.get_dot(_unit)
		if dot_effects:
			for dot in dot_effects:
				Goap.attack.take_hit(dot.attacker, _unit, null, {"damage": dot.damage})
	if has_action_function("on_every_second"):
		get_current_action().on_every_second(self)
	if has_goal_function("on_every_second"):
		_get_best_goal().on_every_second(self)


func on_idle_end():
	if _unit.wait_time > 0:
		_unit.wait_time -= 1
	else:
		_unit.game.test.unit_wait_end(_unit)
	if has_action_function("on_idle_end"):
		get_current_action().on_idle_end(self)
	if has_goal_function("on_idle_end"):
		_get_best_goal().on_idle_end(self)


func on_move_end():
	if has_action_function("on_move_end"):
		get_current_action().on_move_end(self)
	if has_goal_function("on_move_end"):
		_get_best_goal().on_move_end(self)


func on_collision():
	if has_action_function("on_collision"):
		get_current_action().on_collision(self)
	if has_goal_function("on_collision"):
		_get_best_goal().on_collision(self)


func on_stun_end():
	if has_action_function("resume"):
		get_current_action().resume(_unit)
	if has_goal_function("resume"):
		_get_best_goal().resume(_unit)


func on_attack_end():
	if has_action_function("on_attack_end"):
		get_current_action().on_attack_end(self)
	if has_goal_function("on_attack_end"):
		_get_best_goal().on_attack_end(self)
	if _unit.attacks and not _unit.target:
		if _unit.current_path:
			Goap.path.smart(_unit, _unit.current_path)
		elif _unit.current_destiny:
			Goap.move.point(_unit, _unit.current_destiny)
		else:
			Goap.move.stop(_unit)


func was_attacked(attacker, damage):
	self.set_state("being_attacked", attacked_timer)
	self.set_state("attacker", attacker)
	if has_action_function("was_attacked"):
		get_current_action().was_attacked(self, attacker, damage)
	if has_goal_function("was_attacked"):
		_get_best_goal().was_attacked(self, attacker, damage)


func on_animation_end():
	var being_attacked = self.get_state("being_attacked")
	if being_attacked and being_attacked > 0:
		being_attacked -= 1
	else: self.set_state("attacker", null)
	self.set_state("being_attacked", being_attacked)
	if has_action_function("on_animation_end"):
		get_current_action().on_animation_end(self)
	if has_goal_function("on_animation_end"):
		_get_best_goal().on_animation_end(self)


func on_path_arrive():
	if has_action_function("on_path_arrive"):
		get_current_action().on_path_arrive(self)
	if has_goal_function("on_path_arrive"):
		_get_best_goal().on_path_arrive(self)


func on_arrive():
	if has_action_function("on_arrive"):
		get_current_action().on_arrive(self)
	if has_goal_function("on_arrive"):
		_get_best_goal().on_arrive(self)
	match _unit.after_arive:
		"conquer": Goap.orders.conquer_building(_unit)
		"pray": Goap.orders.pray_in_church(_unit)


#func clear_orders():
#	for s in _state:
#		print(s)
#		if("order_" in s):
#			_state.remove(s)
#
#
#func clear_tactics():
#	for s in _state:
#		print(s)
#		if("tactics_" in s):
#			_state.remove(s)
