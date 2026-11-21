extends Node

# Opt-in freeze diagnostic. Attached to the %test node when the game is run
# with `-- --freeze-report`:
#
#   godot --path . -- --freeze-report        # then play a match normally
#
# Every ~2s it samples live, non-building units. Any unit that has been
# stationary for ~6s while NOT attacking an in-range target is reported once
# (then at most every 30s), with its agent goal, current action, plan, and
# state facts — enough to diagnose a stuck unit without a debugger:
#
#   FREEZE_REPORT unit=... goal=NONE action=NONE plan=[] facts={...}
#
# READ-ONLY on purpose: it never calls goal.is_valid() (those mutate stale
# facts by design), never writes state, and is never attached unless the flag
# is passed — so it cannot change gameplay or the golden replay.

const SAMPLE_INTERVAL_MS := 2000
const STILL_SAMPLES := 3  # ~6s stationary before reporting
const MOVED_EPSILON := 2.0
const REPORT_COOLDOWN_MS := 30000

var _last_ms := 0
var _last_pos := {}
var _still := {}
var _last_report := {}


func _ready() -> void:
	_last_ms = Time.get_ticks_msec()
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ms < SAMPLE_INTERVAL_MS:
		return
	_last_ms = now
	_sample(now)


func _sample(now: int) -> void:
	var all_units: Array = WorldState.get_state("all_units")
	if all_units == null:
		return
	for unit in all_units:
		if not is_instance_valid(unit) or unit.dead or unit.agent == null or unit.type == "building":
			continue
		var id = unit.get_instance_id()
		var pos: Vector2 = unit.global_position
		if _last_pos.has(id) and pos.distance_to(_last_pos[id]) < MOVED_EPSILON:
			_still[id] = int(_still.get(id, 0)) + 1
		else:
			_still[id] = 0
		_last_pos[id] = pos
		if int(_still[id]) < STILL_SAMPLES:
			continue
		# Attacking in place is legitimate; anything else should be moving.
		if is_instance_valid(unit.target) and Goap.get_action("ChooseTarget").in_range(unit, unit.target):
			continue
		# Workers between jobs are legitimately idle (cutting, returning).
		var current = unit.agent.get_current_action()
		var current_name: String = current.get_class_name() if current != null else ""
		if unit.type == "worker" or current_name in ["GetLumber", "ReturnLumber", "Hide"]:
			continue
		var last: int = int(_last_report.get(id, -REPORT_COOLDOWN_MS))
		if now - last < REPORT_COOLDOWN_MS:
			continue
		_last_report[id] = now
		_report(unit, pos)


func _report(unit, pos: Vector2) -> void:
	var agent = unit.agent
	var goal = agent._current_goal
	var plan: Array = agent._current_plan if agent._current_plan != null else []
	var plan_names: Array[String] = []
	for action in plan:
		if action != null and action.has_method("get_class_name"):
			plan_names.append(action.get_class_name())
	var current_action = agent.get_current_action()
	var facts := {}
	for key in [
		"lane", "lane_route_finished", "ready_to_fight", "is_retreating",
		"arrived_at_retreat", "is_channeling", "has_player_command", "enemy_dead",
		"enemy_in_attack_range", "has_destiny", "arrived_at_destination",
		"is_stunned", "being_attacked", "tactic",
	]:
		facts[key] = agent.get_state(key)
	var speed: float = Modifiers.get_value(unit, "speed") if unit.agent != null else 0.0
	# Tail of the agent's execution history (goal/plan/action/arrival/movement
	# sub-events) — the "is this unit doing the expected sequence" view.
	var recent: Array = []
	if unit.agent != null and unit.agent.has_method("history_summary"):
		recent = unit.agent.history_summary(8)
	var near := 0
	if "collision_radius" in unit:
		near = Collisions.get_units_in_radius(
			unit.global_position + unit.collision_position,
			maxf(unit.collision_radius * 2.0, 8.0)
		).size()
	print("FREEZE_REPORT unit=%s type=%s team=%s pos=(%.0f,%.0f) state=%s goal=%s action=%s plan=%s target=%s destiny=%s path=%d ffp=%s moves=%s speed=%.1f step=%s near=%d recent=%s facts=%s" % [
		unit.name,
		unit.type,
		unit.team,
		pos.x,
		pos.y,
		unit.state,
		goal.get_class_name() if goal != null else "NONE",
		current_action.get_class_name() if current_action != null else "NONE",
		str(plan_names),
		(unit.target.name if is_instance_valid(unit.target) else "null"),
		str(unit.current_destiny),
		unit.current_path.size() if "current_path" in unit else -1,
		str(agent.frames_til_next_process),
		str(unit.moves),
		speed,
		str(unit.current_step),
		near,
		str(recent),
		str(facts),
	])
