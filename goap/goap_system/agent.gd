extends Node

# self = Goap.Agent

signal plan_changed(plan)
signal goal_changed(goal)
signal action_changed(action)
signal state_changed(goal, action)

@export var goals_list: Array = []

var agent_debug := true

var _goals: Array
var _current_goal
var _current_plan: Array = []
var _current_plan_step := 0
var _unit
var _state: Dictionary = {}

var attacked_timer := 2
var frames_til_next_process:int


func _ready():
	_unit = get_parent()
	frames_til_next_process = randi_range(0,6)
	_goals = []
	if goals_list.size() > 0:
		for goal in goals_list:
			_goals.append(Goap.get_goal(goal))
	
	action_changed.connect(_on_action_changed)

	_unit.unit_reseted.connect(reset)
	_unit.unit_idle_ended.connect(on_idle_end)
	_unit.unit_stun_ended.connect(on_stun_end)
	_unit.unit_attack_ended.connect(on_attack_end)
	_unit.unit_attack_release.connect(on_attack_release)
	_unit.unit_attack_hitted.connect(on_attack_hit)
	_unit.unit_death_started.connect(on_death_started)
	_unit.unit_died.connect(on_died)
	_unit.unit_animation_ended.connect(on_animation_end)
	_unit.unit_was_attacked.connect(was_attacked)
	
	WorldState.second_elapsed.connect(on_every_second)
	
	reset()

func add_goal(goal_name: String) -> void:
	var goal = Goap.get_goal(goal_name)
	if goal and not _goals.has(goal):
		_goals.append(goal)
		goals_list.append(goal_name)


func get_goal(goal_name: String):
	for goal in _goals:
		if goal and goal.has_method("get_class_name") and goal.get_class_name() == goal_name:
			return goal
	return Goap.get_goal(goal_name)


func get_unit():
	return _unit


func get_state(state_name, default = null):
	if _state.has(state_name):
		return _state[state_name]
	return default


func set_state(state_name, value):
	if state_name == "target":
		Goap.get_action("ChooseTarget").set_target(self, value)
		return
	_state[state_name] = value




func erase_state(state_name):
	_state.erase(state_name)


func clear_state():
	_state.clear()


func reset():
	var lane = get_state("lane")
	var tactic = get_state("tactic", "default")
	var unit = get_unit()
	clear_state()
	set_state("target", null)
	set_state("is_stunned", false)
	if lane != null:
		set_state("lane", lane)
	set_state("tactic", tactic)
	if (unit.attacks): set_state("ready_to_fight", true)
	clear_plan()


func get_current_action():
	if (
		_current_plan != null
		and _current_plan_step >= 0
		and _current_plan_step < _current_plan.size()
	):
		return _current_plan[_current_plan_step]
	else:
		return null


func get_current_goal():
	return _current_goal


func has_action_function(func_name):
	var action = get_current_action()
	return action != null and action.has_method(func_name)


func has_goal_function(func_name):
	return _current_goal != null and _current_goal.has_method(func_name)


func clear_plan():
	if _current_goal != null or not _current_plan.is_empty():
		_replace_plan(null, [])


func _exit_current_action():
	var action = get_current_action()
	if action and action.has_method("exit"):
		action.exit(self)


func _replace_plan(goal, plan: Array) -> void:
	_exit_current_action()
	var previous_goal = _current_goal
	if previous_goal != goal and previous_goal:
		previous_goal.exit(self)
	_current_goal = goal
	_current_plan = plan
	_current_plan_step = 0
	if previous_goal != goal:
		goal_changed.emit(goal)
		if goal:
			goal.enter(self)
	var action = get_current_action()
	plan_changed.emit(_current_plan)
	action_changed.emit(action)
	if (goal and action):
		state_changed.emit(goal.get_class_name() + " " + action.get_class_name())




func _on_action_changed(action) -> void:
	if action and action.has_method("enter"):
		action.enter(self)


# On every loop this script checks if the current goal is still
# the highest priority. if it's not, it requests the action planner a new plan
# for the new high priority goal.
func goap_process(delta):
	var goal = _get_best_goal()
	if goal != _current_goal:
		var plan: Array = []
		if goal:
			plan = Goap.get_action_planner().get_plan(self, goal)
		_replace_plan(goal, plan)
	else:
		_follow_plan(_current_plan, delta)


# Returns the highest priority goal available.
func _get_best_goal():
	var highest_priority = null
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
	if plan == null or plan.is_empty() or _current_plan_step >= plan.size():
		return
	var action = plan[_current_plan_step]
	if action == null:
		return
	var is_step_complete = action.perform(self, delta)
		
	if is_step_complete:
		if _current_plan_step < plan.size() - 1:
			if action.has_method("exit"):
				action.exit(self)
			_current_plan_step += 1
			action_changed.emit(get_current_action())
		else:
			_replace_plan(null, [])


func on_every_second() :
	
	if has_action_function("on_every_second"):
		get_current_action().on_every_second(self)
	if has_goal_function("on_every_second"):
		get_current_goal().on_every_second(self)
	
	_unit.regenerate()
	_unit.apply_damage_over_time()


func on_idle_end():
	if _unit.wait_time > 0:
		_unit.wait_time -= 1
	else:
		_unit.game.test.unit_wait_end(_unit)
	if has_action_function("on_idle_end"):
		get_current_action().on_idle_end(self)
	if has_goal_function("on_idle_end"):
		get_current_goal().on_idle_end(self)



func on_attack_release() -> void:
	Goap.get_action("RangeAttack").projectile_release(_unit)


func on_attack_hit() -> void:
	Goap.get_action("MeleeAttack").hit(_unit)


func on_died(unit) -> void:
	Goap.get_action("RangeAttack").clear_stuck(unit)


func on_stun_end():
	if has_action_function("resume"):
		get_current_action().resume(_unit)
	if has_goal_function("resume"):
		get_current_goal().resume(_unit)


func on_attack_end():
	if has_action_function("on_attack_end"):
		get_current_action().on_attack_end(self)
	if has_goal_function("on_attack_end"):
		get_current_goal().on_attack_end(self)


func on_death_started():
	cancel_player_order()


func cancel_player_order():
	clear_plan()
	erase_state("player_order")
	set_state("player_order_complete", true)
	set_state("has_player_command", false)


func was_attacked(attacker, damage):
	set_state("being_attacked", attacked_timer)
	set_state("attacker", attacker)
	if has_action_function("was_attacked"):
		get_current_action().was_attacked(self, attacker, damage)
	if has_goal_function("was_attacked"):
		get_current_goal().was_attacked(self, attacker, damage)


func on_animation_end():
	var being_attacked = get_state("being_attacked")
	if being_attacked and being_attacked > 0:
		being_attacked -= 1
	else: set_state("attacker", null)
	set_state("being_attacked", being_attacked)
	if has_action_function("on_animation_end"):
		get_current_action().on_animation_end(self)
	if has_goal_function("on_animation_end"):
		get_current_goal().on_animation_end(self)


func on_arrive():
	if has_action_function("on_arrive"):
		get_current_action().on_arrive(self)
		
	if has_goal_function("on_arrive"):
		get_current_goal().on_arrive(self)
	
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
