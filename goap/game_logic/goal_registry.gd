# =============================================================================
# GOAP-GUIDE: Goal registry (goap/game_logic/goal_registry.gd)
# =============================================================================
# Name -> goal instance (shared singleton). Which goals a unit evaluates is
# SCENE DATA: the "goals_list" export on its goap_agent node, and
# map/spawns.gd appends WalkLane at spawn.
# Adding a goal: create the script, register it here, then add its name to the
# unit scenes that should consider it.
# =============================================================================

extends Node

# self = Goap.Goals

# Lists all goal contracts.
var _goals: Dictionary = {
	"ArriveAtDestination": preload("res://goap/game_logic/goals/arrive_at_destination.gd").new(),
	"EnemyDefeated": preload("res://goap/game_logic/goals/enemy_defeated.gd").new(),
	"FriendsSafe": preload("res://goap/game_logic/goals/friends_safe.gd").new(),
	"NeedLumber": preload("res://goap/game_logic/goals/need_lumber.gd").new(),
	"NeedSafety": preload("res://goap/game_logic/goals/need_safety.gd").new(),
	"ObeyPlayer": preload("res://goap/game_logic/goals/obey_player.gd").new(),
	"Recover": preload("res://goap/game_logic/goals/recover.gd").new(),
	"WalkLane": preload("res://goap/game_logic/goals/walk_lane.gd").new()
}


func get_goal(goal_name, default = null):
	if _goals.has(goal_name):
		return _goals[goal_name]
	return default


func set_goal(goal_name, value):
	_goals[goal_name] = value
