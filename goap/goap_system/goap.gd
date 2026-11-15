# =============================================================================
# GOAP-GUIDE: Goap autoload (goap/goap_system/goap.gd)
# =============================================================================
# Public API: get_action_planner(), get_goal(name), get_action(name),
#             physics_process(units, delta).
# There is NO move / navigation member -- use Goap.get_action("Move") /
# ("Navigate") and the Navigation autoload.
# Owns      : one shared Planner plus the action and goal registries.
# Pump      : called from game.gd:_physics_process while "is_game_active".
#             Skips dead units and runs each agent every 7th physics tick
#             (frames_til_next_process, seeded randi_range(0,6)) -- at 60 Hz
#             that is ~8.6 Hz per unit. It is deliberately NOT named
#             _physics_process; do not rename it.
# See       : ARCHITECTURE.md "GOAP (the AI core)"; IMPROVEMENT_PLAN.md.
# =============================================================================

extends Node

# Goap global class.
# This class is an autoload accessible globally.
# Access the autoload list in the Godot settings.
#
# Initializes the planner and exposes reusable GOAP/gameplay services.
# In your game, you might want to have different planners
# for different enemy/NPC types, and even change the set
# of actions at runtime.


var _action_planner = preload("res://goap/goap_system/planner.gd").new()
var _actions = preload("res://goap/game_logic/action_registry.gd").new()
var _goals = preload("res://goap/game_logic/goal_registry.gd").new()

# When true, Agent.goap_process logs a planner explanation whenever a selected
# goal yields an EMPTY plan -- the usual "unit is frozen" symptom. Off by
# default (set it from a debugger or a test); see Planner.explain().
var debug_planning := false


func _ready():
	_action_planner.set_actions(_actions.get_all_actions())


func get_action_planner():
	return _action_planner


func get_goal(goal):
	return _goals.get_goal(goal)


func get_action(action):
	return _actions.get_action(action)


func physics_process(units, delta):
	for unit in units:
		if unit.agent and !unit.dead:
			# Staggered cadence: each agent runs every 7th physics tick
			# (~8.6 Hz at 60 Hz physics). Dead units are skipped above.
			if(unit.agent.frames_til_next_process == 0):
				unit.agent.goap_process(delta)
				unit.agent.frames_til_next_process = 6
			else:
				unit.agent.frames_til_next_process -= 1
