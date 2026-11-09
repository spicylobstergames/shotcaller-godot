extends Node

# Smoke runner: boots the REAL game headless and verifies it actually plays.
#
# Enabled by running: godot --headless --path . res://game.tscn -- --smoke [--smoke-ticks=N]
# (test.gd enables its debug harness when --smoke is present, then instantiates
# this node; see tests/test_map/test.gd)
#
# Assertions are deliberately behavioral, not structural:
#   - the game reaches "started" state and loads the map
#   - units exist after spawn
#   - the simulation advances: at least one unit moves over the run
#   - the process exits cleanly with SMOKE_OK
#
# SCRIPT ERRORs cannot be hooked from GDScript; the CI job (and run_suite.sh)
# greps Godot's output for them and fails on any occurrence.

var frames := 0
var frames_target := 600  # ~10 seconds of simulation at 60fps
var start_positions: Dictionary = {}
var pathed_ids: Array = []
var collecting := false
var golden_mode := false
var golden_update := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--smoke-ticks="):
			frames_target = maxi(60, int(arg.split("=")[1]))
	golden_mode = "--golden" in args
	golden_update = "--golden-update" in args
	if golden_mode:
		# Deterministic global RNG stream (game.rng.randomize() is skipped
		# under --golden — see game.gd map_loaded). Pair with --fixed-fps 60
		# so frame deltas are constant.
		seed(20240101)
	await _wait_for_game_started()
	await get_tree().process_frame
	_snapshot_positions()
	collecting = true


func _process(_delta: float) -> void:
	if not collecting:
		return
	frames += 1
	if frames >= frames_target:
		collecting = false
		if golden_mode:
			_golden_report()
		else:
			_report()


func _wait_for_game_started() -> void:
	var waited := 0
	while not WorldState.get_state("game_started") and waited < 600:
		await get_tree().process_frame
		waited += 1
	if not WorldState.get_state("game_started"):
		_fail(["Game never reached game_started=true within 600 frames."])


func _snapshot_positions() -> void:
	start_positions.clear()
	pathed_ids.clear()
	for unit in WorldState.get_state("all_units"):
		if is_instance_valid(unit):
			start_positions[unit.get_instance_id()] = unit.global_position
			# Path-following units progress through MoveAction.calc_step/step.
			# (The advance_with_navigation refinement is dormant by default:
			# Goap.use_native_pathfinding is false, so it is NOT covered here.)
			if "current_path" in unit and not unit.current_path.is_empty():
				pathed_ids.append(unit.get_instance_id())


func _report() -> void:
	var failures: Array[String] = []

	var all_units: Array = WorldState.get_state("all_units")
	var all_leaders: Array = WorldState.get_state("all_leaders")
	var map = WorldState.get_state("map")

	if map == null:
		failures.append("No map was loaded into WorldState.")
	if all_units.size() < 2:
		failures.append("Expected at least 2 spawned units, got %d." % all_units.size())
	if all_leaders.size() < 1:
		failures.append("Expected at least 1 leader, got %d." % all_leaders.size())

	# Behavioral check: the simulation must actually move something.
	var moved := 0
	var pathed_moved := 0
	var alive := 0
	for unit in all_units:
		if not is_instance_valid(unit):
			continue
		alive += 1
		var before = start_positions.get(unit.get_instance_id())
		if before != null and unit.global_position.distance_to(before) > 1.0:
			moved += 1
			if unit.get_instance_id() in pathed_ids:
				pathed_moved += 1
	if moved < 1:
		failures.append("No unit moved during %d frames — simulation appears frozen." % frames)
	if pathed_moved < 1:
		failures.append("No path-following unit moved in %d frames — unit movement (MoveAction) is broken." % frames)
	if alive != all_units.size():
		failures.append("%d of %d units were freed mid-run (unexpected cleanup or crash)." % [all_units.size() - alive, all_units.size()])

	var summary := "frames=%d units=%d leaders=%d moved=%d pathed_moved=%d" % [frames, all_units.size(), all_leaders.size(), moved, pathed_moved]
	if failures.is_empty():
		print("SMOKE_RESULT: ", summary)
		print("SMOKE_OK")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("SMOKE_FAIL: " + f)
		print("SMOKE_RESULT: ", summary)
		print("SMOKE_FAILED")
		get_tree().quit(1)


# Deterministic game-state snapshot for golden replay.
# Positions rounded to 2dp; ticks-based values only — nothing wall-clock
# derived (Time.get_ticks_msec etc. excluded).
func _serialize_state() -> String:
	var lines: Array[String] = []
	var all_units: Array = WorldState.get_state("all_units")
	var sorted_units := all_units.duplicate()
	sorted_units.sort_custom(func(a, b): return a.name < b.name)
	for unit in sorted_units:
		if not is_instance_valid(unit):
			lines.append("FREED")
			continue
		var pos: Vector2 = unit.global_position
		lines.append("%s|%s|%s|hp=%s|lvl=%s|dead=%s|pos=(%s,%s)" % [
			unit.name, unit.type, unit.team,
			unit.current_hp, unit.level, unit.dead,
			snappedf(pos.x, 0.01), snappedf(pos.y, 0.01),
		])
	for key in ["time", "player_kills", "enemy_kills", "player_deaths", "enemy_deaths"]:
		lines.append("%s=%s" % [key, WorldState.get_state(key)])
	return "\n".join(lines)


func _golden_report() -> void:
	var summary := _serialize_state()
	var golden_path := "res://tests/golden/replay_%d.txt" % frames_target
	var failures: Array[String] = []
	var all_units: Array = WorldState.get_state("all_units")
	var moved_count := 0
	for unit in all_units:
		if is_instance_valid(unit):
			var before = start_positions.get(unit.get_instance_id())
			if before != null and unit.global_position.distance_to(before) > 1.0:
				moved_count += 1
	if moved_count < 1:
		failures.append("No unit moved during %d frames — simulation appears frozen." % frames)

	if golden_update:
		DirAccess.make_dir_recursive_absolute("res://tests/golden")
		var f := FileAccess.open(golden_path, FileAccess.WRITE)
		f.store_string(summary)
		f.close()
		print("GOLDEN_UPDATED: %s (%d state lines)" % [golden_path, lines_count(summary)])
	else:
		if not FileAccess.file_exists(golden_path):
			failures.append("Golden file missing: %s (run with --golden-update to create)" % golden_path)
		else:
			var expected := FileAccess.open(golden_path, FileAccess.READ).get_as_text()
			if expected != summary:
				var exp_lines := expected.split("\n")
				var got_lines := summary.split("\n")
				var diff_at := -1
				for i in range(maxi(exp_lines.size(), got_lines.size())):
					var e = exp_lines[i] if i < exp_lines.size() else "<missing>"
					var g = got_lines[i] if i < got_lines.size() else "<missing>"
					if e != g:
						diff_at = i
						failures.append("Golden mismatch at state line %d:\n  expected: %s\n  actual:   %s" % [i, e, g])
						break
				failures.append("State diverged from golden replay (first diff at line %d of %d/%d). If the behavior change is INTENDED, re-record with --golden-update and say why in the commit." % [diff_at, exp_lines.size(), got_lines.size()])

	if failures.is_empty():
		print("GOLDEN_OK: %d state lines identical" % lines_count(summary))
		get_tree().quit(0)
	else:
		for f2 in failures:
			push_error("GOLDEN_FAIL: " + f2)
		print("GOLDEN_FAILED")
		get_tree().quit(1)


func lines_count(summary: String) -> int:
	return summary.split("\n").size()


func _fail(errors: Array) -> void:
	for e in errors:
		push_error("SMOKE_FAIL: " + str(e))
	print("SMOKE_FAILED")
	get_tree().quit(1)
