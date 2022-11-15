#
# This script integrates the unit (NPC) with goap.
# In your implementation you could have this logic
# inside your NPC script.
#
# As good practice, I suggest leaving it isolated like
# this, so it makes re-use easy and it doesn't get tied
# to unrelated implementation details (movement, collisions, etc)
extends Node

class_name GoapAgent

var _goals
var _current_goal
var _current_plan
var _current_plan_step = 0
var _unit
var _state = {}

func get_unit():
	return _unit
	
func get_state(state_name, default = null):
	return _state.get(state_name, default)


func set_state(state_name, value):
	_state[state_name] = value


func clear_state():
	_state = {}

#
# On every loop this script checks if the current goal is still
# the highest priority. if it's not, it requests the action planner a new plan
# for the new high priority goal.
#
func process(delta):
	var goal = _get_best_goal()
	if _current_goal == null or goal != _current_goal:
	# You can set in the blackboard any relevant information you want to use
	# when calculating action costs and status. I'm not sure here is the best
	# place to leave it, but I kept here to keep things simple.
		var blackboard = {
			"position": _unit.position,
		 }
		for s in WorldState._state:
			blackboard[s] = WorldState._state[s]
		for s in _state:
			blackboard[s] = _state[s]

		if(goal != null):
			_current_goal = goal
			_current_plan = Goap.get_action_planner().get_plan(self, _current_goal, blackboard)
			_current_plan_step = 0
			_current_plan[0].enter(self)#works!
	else:
		_follow_plan(_current_plan, delta)#works!


func init(unit, goals: Array):
	_unit = unit
	_goals = goals
	EventMachine.register_listener(Events.ONE_SEC, self, "on_every_second")


#
# Returns the highest priority goal available.
#
func _get_best_goal():
	var highest_priority

	for goal in _goals:
		if goal.is_valid(self) and (highest_priority == null or goal.priority(self) > highest_priority.priority(self)):
			highest_priority = goal

	return highest_priority


#
# Executes plan. This function is called on every game loop.
# "plan" is the current list of actions, and delta is the time since last loop.
#
# Every action exposes a function called perform, which will return true when
# the job is complete, so the agent can jump to the next action in the list.
#
func _follow_plan(plan, delta):
	if plan.size() == 0:
		return

	var is_step_complete = plan[_current_plan_step].perform(self, delta)
	if is_step_complete:
		_current_plan[_current_plan_step].exit(self) #untested
		if _current_plan_step < plan.size() - 1:
			_current_plan_step += 1
			_current_plan[_current_plan_step].enter(self)
		else:
			_current_goal = null #trigger replan
			_current_plan = null

func on_every_second() :
	if(_current_plan != null):
		_current_plan[_current_plan_step].on_every_second(self)

func on_arrive():
	if(_current_plan != null):
		_current_plan[_current_plan_step].on_arrive(self)
