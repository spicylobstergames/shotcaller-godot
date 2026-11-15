extends RefCounted

# Track B regression: arrival dispatch and the ReturnLumber entry point.
#
# Unit.on_arrive() emits `unit_arrived`; Collisions calls it when a moving unit
# reaches current_destiny (after ArriveAtDestination.on_arrive advances the
# path). Agent._ready() must connect that signal to Agent.on_arrive, which
# fires the current action's and goal's on_arrive hooks. Before this fix
# nothing connected the signal, so every action on_arrive hook was dead
# (GetLumber never set has_wood, Hide never hid, RetreatAction never set
# arrived_at_retreat, OrderAction never conquered/prayed).
#
# Also covers ReturnLumber.enter, which used to assign the null return of
# agent.set_state() to a nonexistent unit property and never move the unit.

const Agent = preload("res://goap/goap_system/agent.gd")
const ReturnLumber = preload("res://goap/game_logic/actions/return_lumber.gd")
const WorldStateSnapshot = preload("res://tests/helpers/world_state_snapshot.gd")
const Pathfinder = preload("res://pathfind/jump_point_finder.gd")


# Real Node double: declares the same signals as Unit (Agent._ready connects
# them all) plus the movement/combat properties the wired code touches.
class TestUnit:
	extends Node

	signal unit_reseted
	signal unit_idle_ended
	signal unit_stun_ended
	signal unit_attack_ended
	signal unit_attack_release
	signal unit_attack_hitted
	signal unit_death_started
	signal unit_died(unit)
	signal unit_animation_ended
	signal unit_was_attacked(attacker, damage)
	signal unit_arrived

	var moves := true
	var speed := 100.0
	var attacks := true
	var dead := false
	var state := "idle"
	var target = null
	var last_target = null
	var attack_count := 0
	var current_modifiers: Dictionary = {}
	var current_path: Array = []
	var current_destiny := Vector2.ZERO
	var final_destiny := Vector2.ZERO
	var global_position := Vector2.ZERO
	var angle := 0.0
	var current_step := Vector2.ZERO
	var animations = null
	var agent = null

	func set_state(s):
		state = s

	func mirror_look_at(_point):
		pass


class TestMap:
	extends Node2D
	var tile_size := 64
	var half_tile_size := 32
	var size := Vector2(320, 320)


class ArrivalAction:
	extends RefCounted
	var arrived_count := 0

	func enter(_agent) -> void:
		pass

	func perform(_agent, _delta: float) -> bool:
		return false

	func exit(_agent) -> void:
		pass

	func on_arrive(_agent) -> void:
		arrived_count += 1

	func get_class_name() -> String:
		return "ArrivalAction"


class ArrivalGoal:
	extends RefCounted
	var arrived_count := 0

	func is_valid(_agent) -> bool:
		return true

	func priority(_agent) -> int:
		return 1

	func get_desired_state(_agent) -> Dictionary:
		return {"arrival_dispatch_probe": true}

	func enter(_agent) -> void:
		pass

	func exit(_agent) -> void:
		pass

	func on_arrive(_agent) -> void:
		arrived_count += 1

	func get_class_name() -> String:
		return "ArrivalGoal"


func run(harness) -> void:
	var ws = WorldStateSnapshot.new()
	var unit = TestUnit.new()
	unit.current_modifiers = Modifiers.new_modifiers()
	var agent = Agent.new()
	unit.add_child(agent)
	# add_child on a detached subtree does not fire _ready; run the production
	# wiring explicitly so the unit_arrived connection under test is real.
	agent._ready()
	unit.agent = agent

	# --- Agent._ready wiring ---
	harness.check(
		unit.unit_arrived.is_connected(agent.on_arrive),
		"Agent._ready connects unit_arrived to Agent.on_arrive."
	)

	# --- dispatch to the current action and goal ---
	var goal = ArrivalGoal.new()
	var action = ArrivalAction.new()
	agent._replace_plan(goal, [action])
	unit.unit_arrived.emit()
	harness.check_equal(
		action.arrived_count,
		1,
		"unit_arrived dispatches once to the current action's on_arrive."
	)
	harness.check_equal(
		goal.arrived_count, 1, "unit_arrived dispatches once to the current goal's on_arrive."
	)
	# A second connection would make every emission fire twice.
	unit.unit_arrived.emit()
	harness.check_equal(
		action.arrived_count, 2, "Each emission dispatches exactly once (no double connection)."
	)

	# --- ReturnLumber.enter navigates instead of assigning set_state()'s null ---
	var map = TestMap.new()
	harness.add_child(map)
	ws.set_state("map", map)
	var old_grid = Navigation.path_grid
	var old_finder = Navigation.path_finder
	Navigation.path_grid = Pathfinder.GridGD.new().Grid.new(5, 5)
	Navigation.path_finder = Pathfinder.JumpPointFinder.new()

	var deliver_position := Vector2(160, 160)
	unit.global_position = Vector2(96, 96)
	unit.current_destiny = Vector2.ZERO
	unit.final_destiny = Vector2.ZERO
	agent.set_state("deliver_position", deliver_position)
	ReturnLumber.new().enter(agent)

	harness.check_equal(
		unit.final_destiny,
		deliver_position,
		"ReturnLumber.enter routes the unit to deliver_position."
	)
	harness.check_equal(
		unit.state, "move", "ReturnLumber.enter starts the unit moving (no null-property assignment)."
	)
	harness.check(
		unit.current_destiny != Vector2.ZERO,
		"ReturnLumber.enter pops a real first waypoint into current_destiny."
	)

	Navigation.path_grid = old_grid
	Navigation.path_finder = old_finder
	map.free()
	ws.restore()
	unit.free()
