extends Node

# self = Goap.Agent

@export var goals_list: Array = []

var agent_debug := true

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
	if _unit.type == "leader":
		_goals.append(Goap.get_goal("ObeyPlayer"))

	_unit.unit_reseted.connect(reset)
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
	_exit_current_action()
	clear_state()
	_current_goal = null
	_current_plan = []
	_current_plan_step = 0


func get_current_action():
	if (
		_current_plan != null
		and _current_plan_step >= 0
		and _current_plan_step < _current_plan.size()
	):
		return _current_plan[_current_plan_step]
	else:
		return null


func has_action_function(func_name):
	var action = get_current_action()
	return action != null and action.has_method(func_name)


func has_goal_function(func_name):
	var goal = _get_best_goal()
	return goal != null and goal.has_method(func_name)


func issue_player_order(order_type: String, target: Vector2 = Vector2.ZERO) -> bool:
	const supported_orders = ["move", "advance", "attack", "lane", "teleport", "stand"]
	if (
		_unit == null
		or _unit.type != "leader"
		or not _unit.is_controllable()
		or _unit.dead
		or order_type not in supported_orders
	):
		return false

	_exit_current_action()
	Goap.move.stop(_unit)
	_unit.current_path.clear()
	_state["is_channeling"] = false
	_state["player_order_id"] = get_state("player_order_id", 0) + 1
	_state["player_order"] = {"type": order_type, "target": target}
	_state["player_order_complete"] = false
	_state["has_player_command"] = true
	_current_goal = null
	_current_plan = []
	_current_plan_step = 0
	Goap.attack.set_target(_unit, null)
	_unit.start_control_delay()
	return true


func complete_player_order():
	_state.erase("player_order")
	_state["player_order_complete"] = true
	_state["has_player_command"] = false


func cancel_player_order():
	_exit_current_action()
	_state.erase("player_order")
	_state["player_order_complete"] = false
	_state["has_player_command"] = false
	_current_goal = null
	_current_plan = []
	_current_plan_step = 0


func _exit_current_action():
	var action = get_current_action()
	if action and action.has_method("exit"):
		action.exit(self)



# On every loop this script checks if the current goal is still
# the highest priority. if it's not, it requests the action planner a new plan
# for the new high priority goal.
func process(delta):
	var goal = _get_best_goal()
	if _current_goal == null or goal != _current_goal:
		_exit_current_action()
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
		
	# debug
	if agent_debug and _unit.hud and _unit.hud.state:
		var goal = _get_best_goal()
		if goal:
			_unit.hud.state.text = goal.get_class_name()
		
	if is_step_complete:
		if action.has_method("exit"):
			action.exit(self)
		if _current_plan_step < plan.size() - 1:
			_current_plan_step += 1
			var next_action = get_current_action()
			if next_action and next_action.has_method("enter"):
				next_action.enter(self)
		else:
			_current_goal = null
			_current_plan = []
			_current_plan_step = 0


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
	var order = get_state("player_order", {})
	if order.get("type", "") == "attack":
		complete_player_order()
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
