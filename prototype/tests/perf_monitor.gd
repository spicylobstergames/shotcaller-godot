extends Node

# Perf monitor: samples engine/game counters once per wall-clock second
# while the game runs. Enabled with -- --perf on game.tscn (wired via
# tests/debug_map.gd, which runs the debug scenario on the three-lane map
# with the real wave economy). Read-only diagnostic — never part of
# run_suite.sh gating.
#
# What the columns are for (see the fps-decay diagnosis in COVERAGE.md):
#   units — total entries in all_units (grows without bound; nothing erases
#           dead units — the root cause of the gradual fps decay)
#   dead  — dead units still in all_units (still fully simulated by the
#           GOAP pump every tick)
#   dup   — duplicate node entries in all_units (cemetery recycling)
#   nodes/objs/mem — distinguish "growing work" (flat memory, rising
#           per-tick cost) from a genuine leak (rising memory)

var ticks := 0
var last_ms := 0
var last_ticks := 0
var frames := 0


func _ready() -> void:
	var waited := 0
	while not WorldState.get_state("game_started") and waited < 600:
		await get_tree().process_frame
		waited += 1
	last_ms = Time.get_ticks_msec()
	set_process(true)


func _process(_delta: float) -> void:
	frames += 1
	var now: int = Time.get_ticks_msec()
	if now - last_ms < 1000:
		return
	var wall_dt: float = (now - last_ms) / 1000.0
	last_ms = now
	var ticks_per_s := (ticks - last_ticks) / wall_dt
	last_ticks = ticks

	var all_units: Array = WorldState.get_state("all_units")
	var dead := 0
	var ids := {}
	var duplicates := 0
	for unit in all_units:
		if not is_instance_valid(unit):
			continue
		if unit.dead:
			dead += 1
		var id = unit.get_instance_id()
		if ids.has(id):
			duplicates += 1
		ids[id] = true

	print("PERF: t=%3.0fs fps=%4d ticks/s=%3.0f units=%4d dead=%3d dup=%3d nodes=%5d objs=%6d mem=%dMB" % [
		now / 1000.0,
		frames / wall_dt,
		ticks_per_s,
		all_units.size(),
		dead,
		duplicates,
		get_tree().get_node_count(),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		OS.get_static_memory_usage() / 1048576,
	])
	frames = 0


func _physics_process(_delta: float) -> void:
	ticks += 1
