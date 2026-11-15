extends RefCounted

# Track E4: WorldState.setup_timers()/setup_spawn_timers() used to create and
# add a NEW Timer on every call without stopping/freeing the old one, so a
# second game.start() stacked a second live one-second timer (double regen,
# double per-second ticks) and a second spawn timer. game.gd additionally
# connects one_sec_cycle to the fresh timer on every start, so teardown (not
# reuse) is the fix: the old timer's connections must die with it.

const WorldStateScript = preload("res://goap/game_logic/world_state.gd")


func _count_live_timers(ws) -> int:
	var live := 0
	for child in ws.get_children():
		if child is Timer and not child.is_queued_for_deletion():
			live += 1
	return live


func run(harness) -> void:
	# --- first setup installs exactly one timer of each kind ---
	var ws = WorldStateScript.new()
	ws.setup_timers()
	ws.setup_spawn_timers(5.0)
	harness.check_equal(
		_count_live_timers(ws), 2,
		"First setup installs exactly one one-second and one spawn timer."
	)
	var first_one_sec = ws.one_sec_timer
	var first_spawn = ws.spawn_timer

	# --- the fresh one-second timer relays timeout -> second_elapsed ---
	var relay_hits := [0]
	ws.second_elapsed.connect(func(): relay_hits[0] += 1)
	first_one_sec.timeout.emit()
	harness.check_equal(
		relay_hits[0], 1,
		"The one-second timer's timeout is relayed through second_elapsed."
	)

	# --- a second setup replaces the timers instead of stacking them ---
	ws.setup_timers()
	ws.setup_spawn_timers(5.0)
	harness.check(
		ws.one_sec_timer != first_one_sec and ws.spawn_timer != first_spawn,
		"A second setup installs fresh timer instances."
	)
	harness.check(
		first_one_sec.is_queued_for_deletion() and first_spawn.is_queued_for_deletion(),
		"The previous timers are stopped and freed by the second setup."
	)
	harness.check_equal(
		_count_live_timers(ws), 2,
		"Double setup leaves exactly one live one-second and one live spawn timer."
	)
	harness.check_equal(
		String(ws.one_sec_timer.name), "one_sec_timer",
		"The replacement one-second timer keeps its canonical name."
	)
	harness.check_equal(
		String(ws.spawn_timer.name), "unit_spawn_timer",
		"The replacement spawn timer keeps its canonical name."
	)

	# --- the relay is wired on the replacement timer too ---
	relay_hits[0] = 0
	ws.one_sec_timer.timeout.emit()
	harness.check_equal(
		relay_hits[0], 1,
		"The replacement timer is connected to second_elapsed."
	)

	# --- stop_timers is safe before any setup (scoreboard calls it at game end) ---
	var fresh = WorldStateScript.new()
	fresh.stop_timers()
	harness.check(
		true,
		"stop_timers() before setup does not crash on unset timers."
	)
	fresh.free()

	ws.free()
