extends RefCounted

# State-fact lint: every string key the GOAP code uses must be documented in
# docs/ai/world-state.md, and every required fact must have a producer.
#
# This is the guard against the codebase's most silent failure mode: a typo or
# a new key that the planner then never matches (null != false). A weaker
# agent gets a named failure instead of a frozen unit.
#
# See ARCHITECTURE.md "State facts" and IMPROVEMENT_PLAN.md Track D5.

const GoapScan = preload("res://tests/helpers/goap_scan.gd")


func run(harness) -> void:
	var scan = GoapScan.new()
	scan.scan()

	harness.check(
		scan.files.size() >= 35,
		"State-key scan covered the GOAP tree (%d scripts)." % scan.files.size()
	)
	harness.check(
		scan.required.size() >= 12,
		"State-key scan found precondition/desired-state keys (%d)." % scan.required.size()
	)
	harness.check(
		scan.undocumented.is_empty(),
		(
			"Every GOAP state key is documented in docs/ai/world-state.md. Undocumented: %s"
			% [", ".join(scan.undocumented)]
		)
	)
	harness.check(
		scan.unproduced.is_empty(),
		(
			"Every required fact has a producer (an action effect or a *_state() writer). Unproduced: %s"
			% [", ".join(scan.unproduced)]
		)
	)
