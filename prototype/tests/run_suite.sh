#!/usr/bin/env bash
# Runs the full verification suite for shotcaller-godot.
#
#   ./tests/run_suite.sh [godot-binary]
#
# Checks:
#   1. Unit/integration test suite (headless)
#   2. Boot smoke test: boots the REAL game and simulates gameplay
#   3. Script-error budget: ANY "SCRIPT ERROR" in any run fails the suite
#
# Golden replay (step 4 upstream of this port) is DEFERRED until the GOAP
# restructure settles — the recorded checkpoints pin pre-restructure
# behavior. See COVERAGE.md ("Deferred coverage"). Re-add the step together
# with the deferred GOAP suites and re-record with --golden-update.
#
# Exit codes: 0 = all green, 1 = failures (see output).
set -u

# Per-step timeout in seconds — a runner that never quits must fail, not hang.
STEP_TIMEOUT="${STEP_TIMEOUT:-180}"

# Expected number of unit-suite assertions. This pins the count in a DIFFERENT
# file than the reporter: a runner that crashes, hangs, or is bypassed cannot
# fake a green result without editing both files. Bump this when you add
# tests — the suite will fail with the actual count until you do.
EXPECTED_UNIT_TESTS="${EXPECTED_UNIT_TESTS:-93}"

# Godot binary: argument > GODOT env var > "godot" on PATH.
GODOT="${1:-${GODOT:-godot}}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SMOKE_TICKS="${SMOKE_TICKS:-300}"

# Keep Godot's user-data writes inside the repo (sandbox/CI friendly).
export HOME="${GODOT_HOME:-$PROJECT_DIR/../.godot-home}"
mkdir -p "$HOME"

LOG_DIR="$PROJECT_DIR/../.test-logs"
mkdir -p "$LOG_DIR"

failures=0

echo "=== [0/2] Build Godot resource/class cache (needed on fresh checkouts) ==="
timeout "$STEP_TIMEOUT" "$GODOT" --headless --import --path "$PROJECT_DIR" > "$LOG_DIR/import.log" 2>&1
import_rc=$?
if [ "$import_rc" -ne 0 ]; then
	echo "FAIL: --import exited $import_rc — see $LOG_DIR/import.log"
	failures=$((failures + 1))
fi
if [ ! -f "$PROJECT_DIR/.godot/global_script_class_cache.cfg" ]; then
	echo "FAIL: --import did not produce the global script class cache — see $LOG_DIR/import.log"
	failures=$((failures + 1))
fi

echo "=== [1/2] Unit + integration suite ==="
timeout "$STEP_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" res://tests/test_runner.tscn \
	> "$LOG_DIR/suite.log" 2>&1
suite_rc=$?
grep -E "TESTS_COMPLETE|All .* tests passed|tests failed" "$LOG_DIR/suite.log" | tail -2
errors=$(grep -c "SCRIPT ERROR" "$LOG_DIR/suite.log" || true)

# The result is never taken on faith: the runner must emit the completion
# token, report zero failures, and report a plausible number of executed tests.
token_line=$(grep -E "^TESTS_COMPLETE: passed=[0-9]+ failed=[0-9]+$" "$LOG_DIR/suite.log" | tail -1)
if [ -z "$token_line" ]; then
	echo "FAIL: unit suite never emitted TESTS_COMPLETE token (runner crashed, hung, or was bypassed)"
	failures=$((failures + 1))
else
	passed=$(echo "$token_line" | sed -E 's/TESTS_COMPLETE: passed=([0-9]+) failed=[0-9]+/\1/')
	failed=$(echo "$token_line" | sed -E 's/TESTS_COMPLETE: passed=[0-9]+ failed=([0-9]+)/\1/')
	if [ "$failed" -ne 0 ]; then
		echo "FAIL: unit suite reports $failed failed test(s)"
		failures=$((failures + 1))
	fi
	if [ "$passed" -ne "$EXPECTED_UNIT_TESTS" ]; then
		echo "FAIL: unit suite ran $passed test(s), expected $EXPECTED_UNIT_TESTS (update EXPECTED_UNIT_TESTS in run_suite.sh when adding tests)"
		failures=$((failures + 1))
	fi
fi
if [ "$suite_rc" -ne 0 ]; then
	echo "FAIL: unit suite exited $suite_rc"
	failures=$((failures + 1))
fi
if [ "$errors" -gt 0 ]; then
	echo "FAIL: unit suite produced $errors SCRIPT ERROR(s) — see $LOG_DIR/suite.log"
	grep "SCRIPT ERROR" "$LOG_DIR/suite.log" | sort -u | head -10
	failures=$((failures + 1))
fi

echo "=== [2/2] Boot smoke test ($SMOKE_TICKS ticks of the real game) ==="
timeout "$STEP_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" res://game.tscn -- \
	--smoke --smoke-ticks="$SMOKE_TICKS" \
	> "$LOG_DIR/smoke.log" 2>&1
smoke_rc=$?
grep -E "SMOKE_RESULT" "$LOG_DIR/smoke.log" | tail -1
errors=$(grep -c "SCRIPT ERROR" "$LOG_DIR/smoke.log" || true)
if [ "$smoke_rc" -ne 0 ] || ! grep -q "SMOKE_OK" "$LOG_DIR/smoke.log"; then
	echo "FAIL: boot smoke exited $smoke_rc — see $LOG_DIR/smoke.log"
	grep -E "SMOKE_FAIL|SCRIPT ERROR" "$LOG_DIR/smoke.log" | sort -u | head -10
	failures=$((failures + 1))
fi
if [ "$errors" -gt 0 ]; then
	echo "FAIL: boot smoke produced $errors SCRIPT ERROR(s)"
	grep "SCRIPT ERROR" "$LOG_DIR/smoke.log" | sort -u | head -10
	failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
	echo "=== SUITE GREEN: unit tests, boot smoke, zero script errors (golden replay deferred — see COVERAGE.md) ==="
	exit 0
else
	echo "=== SUITE RED: $failures check group(s) failed ==="
	exit 1
fi
