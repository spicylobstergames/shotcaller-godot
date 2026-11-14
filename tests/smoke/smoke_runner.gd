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
var checkpoint_frames: Array = []
var checkpoints: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--smoke-ticks="):
			frames_target = maxi(60, int(arg.split("=")[1]))
	golden_mode = "--golden" in args
	golden_update = "--golden-update" in args
	if golden_mode:
		# Intermediate checkpoints (1/3, 2/3, final): a behavior that diverges
		# mid-run and converges by the final frame still trips an earlier one.
		# intermediate checkpoints; the final frame is captured by the done-branch
		checkpoint_frames = [int(frames_target / 3.0), int(frames_target * 2.0 / 3.0)]
	if golden_mode:
		# Deterministic global RNG stream (game.rng.randomize() is skipped
		# under --golden — see game.gd map_loaded). Pair with --fixed-fps 60
		# so frame deltas are constant.
		seed(20240101)
	await _wait_for_game_started()
	await get_tree().process_frame
	# Settle delay: unit paths are assigned by the GOAP planner (WalkLane)
	# a few frames after game start — snapshot too early and no unit is
	# pathed yet, which would misreport healthy movement as broken.
	var settled := 0
	while settled < 30:
		await get_tree().process_frame
		settled += 1
	_snapshot_positions()
	collecting = true


func _process(_delta: float) -> void:
	if not collecting:
		return
	frames += 1
	if golden_mode and frames in checkpoint_frames and checkpoints.size() < checkpoint_frames.size():
		checkpoints.append(_serialize_state())  # intermediate
	if frames >= frames_target:
		collecting = false
		if golden_mode:
			_golden_report()  # captures the final-frame checkpoint itself
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
	# NOTE: lane-path-following movement (WalkLane/MoveAction) is covered by
	# the DEFERRED GOAP suite (see COVERAGE.md) — on the live map units that
	# see an enemy go straight to PursueEnemy/AttackEnemy and may never hold
	# a lane path, so "a pathed unit moved" is not a boot-smoke-level fact.
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
	# Sort by the NORMALIZED identity (generated-name counters stripped) plus
	# stable fields and position — sorting by raw node names would make the
	# output order depend on allocation counters that normalization removes.
	sorted_units.sort_custom(func(a, b):
		var ka := _unit_sort_key(a)
		var kb := _unit_sort_key(b)
		if ka != kb:
			return ka < kb
		if absf(a.global_position.x - b.global_position.x) > 0.001:
			return a.global_position.x < b.global_position.x
		return a.global_position.y < b.global_position.y)
	for unit in sorted_units:
		if not is_instance_valid(unit):
			lines.append("FREED")
			continue
		var pos: Vector2 = unit.global_position
		lines.append("%s|%s|%s|hp=%d|lvl=%d|dead=%s|pos=(%.2f,%.2f)" % [
			_normalize_node_name(String(unit.name)), unit.type, unit.team,
			int(unit.current_hp), int(unit.level), unit.dead, pos.x, pos.y,
		])
	for key in ["time", "player_kills", "enemy_kills", "player_deaths", "enemy_deaths"]:
		lines.append("%s=%s" % [key, WorldState.get_state(key)])
	return "\n".join(lines)

# Generated node names ("@StaticBody2D@83") embed allocation counters that
# can shift across engine versions/platforms: keep the class, drop the
# counter. See DECISIONS.md D10.
func _unit_sort_key(unit) -> String:
	return "%s|%s|%s" % [
		_normalize_node_name(String(unit.name)), unit.type, unit.team,
	]


func _normalize_node_name(n: String) -> String:
	if n.begins_with("@"):
		var parts := n.split("@")
		if parts.size() >= 3:
			return "@%s@#" % parts[1]
	return n

# Field-wise comparison: strings exact, numbers within tolerance
# (platform float drift must not read as a gameplay regression).
func _states_match(expected: String, actual: String, out_diff: Array) -> bool:
	var exp_lines: PackedStringArray = expected.split("\n")
	var got_lines: PackedStringArray = actual.split("\n")
	if exp_lines.size() != got_lines.size():
		out_diff.append("state line count differs: %d expected vs %d actual" % [exp_lines.size(), got_lines.size()])
		return false
	for i in range(exp_lines.size()):
		if not _lines_match(exp_lines[i], got_lines[i]):
			out_diff.append("state line %d differs:\n  expected: %s\n  actual:   %s" % [i, exp_lines[i], got_lines[i]])
			return false
	return true

func _lines_match(exp: String, got: String) -> bool:
	# POSITIONS get tolerance (platform float drift in movement), and HP gets
	# a tolerance of exactly 1: units regenerate +1 hp per second, and under
	# the staggered agent cadence (goap_process every 7th physics tick) the
	# 1-second regen tick straddles a checkpoint boundary ~50% of the time —
	# observed as a 9910 vs 9911 flip on the smoke pawn at frame 100. A real
	# gameplay change shifts hp by a hit (~45), never by 1.
	# Every other field is an exact state fact and must fail the comparison.
	# See DECISIONS.md D10.
	var exp_f := exp.split("|")
	var got_f := got.split("|")
	if exp_f.size() != got_f.size():
		return exp == got
	for i in range(exp_f.size()):
		var e := exp_f[i]
		var g := got_f[i]
		if e == g:
			continue
		if e.begins_with("pos=(") and g.begins_with("pos=("):
			if not _pos_close(e, g):
				return false
		elif e.begins_with("hp=") and g.begins_with("hp="):
			if abs(int(e.trim_prefix("hp=")) - int(g.trim_prefix("hp="))) > 1:
				return false
		else:
			return false
	return true

func _frame_label(c: int) -> int:
	# The final checkpoint has no entry in checkpoint_frames — its frame
	# label is frames_target itself. Indexing checkpoint_frames[c] for the
	# last checkpoint is out of bounds and would mask the real diagnostic.
	return checkpoint_frames[c] if c < checkpoint_frames.size() else frames_target


func _pos_close(e: String, g: String) -> bool:
	var e_coords = e.trim_prefix("pos=(").trim_suffix(")").split(",")
	var g_coords = g.trim_prefix("pos=(").trim_suffix(")").split(",")
	if e_coords.size() != 2 or g_coords.size() != 2:
		return false
	for i in range(2):
		if absf(e_coords[i].to_float() - g_coords[i].to_float()) > 0.51:
			return false
	return true

func _golden_report() -> void:
	checkpoints.append(_serialize_state())  # final frame
	var failures: Array[String] = []
	var all_units: Array = WorldState.get_state("all_units")
	var moved_count := 0
	for unit in all_units:
		if is_instance_valid(unit):
			var before = start_positions.get(unit.get_instance_id())
			if before != null and unit.global_position.distance_to(before) > 1.0:
				moved_count += 1
	if moved_count < 1:
		failures.append("No unit moved during %d frames - simulation appears frozen." % frames)

	var summary := _format_checkpoints()
	var golden_path := "res://tests/golden/replay_%d.txt" % frames_target

	if golden_update:
		DirAccess.make_dir_recursive_absolute("res://tests/golden")
		var f := FileAccess.open(golden_path, FileAccess.WRITE)
		f.store_string(summary)
		f.close()
		print("GOLDEN_UPDATED: %s (%d checkpoints)" % [golden_path, checkpoints.size()])
	else:
		if not FileAccess.file_exists(golden_path):
			failures.append("Golden file missing: %s (run with --golden-update to create)" % golden_path)
		else:
			var expected := FileAccess.open(golden_path, FileAccess.READ).get_as_text()
			var exp_sections := _split_checkpoints(expected)
			if exp_sections.size() != checkpoints.size():
				failures.append("Golden file has %d checkpoints, run produced %d - re-record with --golden-update" % [exp_sections.size(), checkpoints.size()])
			else:
				for c in range(checkpoints.size()):
					var diff: Array = []
					if not _states_match(exp_sections[c], checkpoints[c], diff):
						failures.append("Golden mismatch at checkpoint %d (frame %d):\n%s" % [c + 1, _frame_label(c), "\n".join(diff)])
						failures.append("If this divergence is an INTENDED behavior change, re-record with --golden-update and say why in the commit.")
						break

	if failures.is_empty():
		print("GOLDEN_OK: %d checkpoints identical" % checkpoints.size())
		get_tree().quit(0)
	else:
		for f2 in failures:
			push_error("GOLDEN_FAIL: " + f2)
		print("GOLDEN_FAILED")
		get_tree().quit(1)

func _format_checkpoints() -> String:
	var out := ""
	for c in range(checkpoints.size()):
		out += "=== checkpoint %d (frame %d) ===\n%s" % [c + 1, _frame_label(c), checkpoints[c]]
		if c < checkpoints.size() - 1:
			out += "\n"
	return out

func _split_checkpoints(text: String) -> Array:
	var sections: Array = []
	var current: Array[String] = []
	for line in text.split("\n"):
		if line.begins_with("=== checkpoint"):
			if current.size() > 0:
				sections.append("\n".join(current))
				current = []
		elif line != "":
			current.append(line)
	if current.size() > 0:
		sections.append("\n".join(current))
	return sections

func _fail(errors: Array) -> void:
	for e in errors:
		push_error("SMOKE_FAIL: " + str(e))
	print("SMOKE_FAILED")
	get_tree().quit(1)
