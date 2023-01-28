extends Node

# self = Goap.Agent

# This script integrates the unit (NPC) with goap.
# In your implementation you could have this logic
# inside your NPC script.
#
# As good practice, I suggest leaving it isolated like
# this, so it makes re-use easy and it doesn't get tied
# to unrelated implementation details (movement, collisions, etc)

export var goals = []

var _goals
var _current_goal
var _current_plan
var _current_plan_step = 0
var _unit
var _state = {}


func _ready():
	_unit = get_parent()
	_goals = []
	
	if goals.size() > 0:
		for goal in goals:
			_goals.push_back(Goap.get_goal(goal))
	
	_unit.connect("unit_reseted", self, "reset")
	_unit.connect("unit_collided", self, "on_collision")
	_unit.connect("unit_arrived_on_path", self, "on_path_arrive")
	_unit.connect("unit_arrived", self, "on_arrive")
	_unit.connect("unit_idle_ended", self, "on_idle_end")
	_unit.connect("unit_stun_ended", self, "on_stun_end")
	_unit.connect("unit_move_ended", self, "on_move_end")
	_unit.connect("unit_attack_ended", self, "on_attack_end")
	_unit.connect("unit_animation_ended", self, "on_animation_end")
	
	WorldState.one_sec_timer.connect("timeout", self, "on_every_second")


func get_unit():
	return _unit


func get_state(state_name, default = null):
	return _state.get(state_name, default)


func set_state(state_name, value):
	_state[state_name] = value


func clear_state():
	_state = {}


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
	return get_current_action() != null and get_current_action().has_method(func_name)


# On every loop this script checks if the current goal is still
# the highest priority. if it's not, it requests the action planner a new plan
# for the new high priority goal.
func process(delta):
	var goal = _get_best_goal()
	if _current_goal == null or goal != _current_goal:
		if (goal != null):
			_current_goal = goal
			if (_current_plan): _current_plan[_current_plan_step].exit(self)
			_current_plan = Goap.get_action_planner().get_plan(self, _current_goal)
			_current_plan_step = 0
			if (_current_plan.size() > 0):
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
		if WorldState.game.test.unit: 
			_unit.hud.state.text = get_current_action().get_class()
			#_unit.hud.state.text = _get_best_goal().get_class()
		
		if is_step_complete:
			get_current_action().exit(self) #untested
			if _current_plan_step < plan.size() - 1:
				_current_plan_step += 1
				get_current_action().enter(self)
			else:
				#clear_commands()
				_current_goal = null #trigger replan
				_current_plan = null


func on_idle_end():
	if has_action_function("on_idle_end"):
		get_current_action().on_idle_end(self)


func on_move_end():
	if has_action_function("on_move_end"):
		get_current_action().on_move_end(self)


func on_collision():
	if has_action_function("on_collision"):
		get_current_action().on_collision(self)


func on_every_second() :
	if has_action_function("on_every_second"):
		get_current_action().on_every_second(self)


func on_stun_end():
	if has_action_function("resume"):
		get_current_action().resume(_unit)


func on_attack_end():
	if has_action_function("on_attack_end"):
		get_current_action().on_attack_end(self)


func on_animation_end():
	if has_action_function("on_animation_end"):
		get_current_action().on_animation_end(self)


func on_path_arrive():
	if has_action_function("point"):
		get_current_action().point(_unit, _unit.current_path.pop_front())


func on_arrive():
	if has_action_function("on_arrive"):
		get_current_action().on_arrive(self)


func clear_commands():
	for s in _state:
		if("command_" in s):
			print("erased")
			print(s)
			_state.erase(s)

func clear_orders():
	for s in _state:
		if("order_" in s):
			_state.remove(s)

func clear_tactics():
	for s in _state:
		if("tactics_" in s):
			_state.remove(s)
