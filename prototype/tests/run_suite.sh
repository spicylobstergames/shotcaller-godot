#!/usr/bin/env bash
# Runs the full verification suite for shotcaller-godot.
#
#   ./tests/run_suite.sh [godot-binary]
#
# Checks:
#   1. Unit/integration test suite (headless)
#   2. Boot smoke test: boots the REAL game and simulates gameplay
#   3. Script-error budget: ANY "SCRIPT ERROR" in either run fails the suite
#
# Exit codes: 0 = all green, 1 = failures (see output).
set -u

GODOT="${1:-/home/john/Downloads/godot472/Godot_v4.7.2-stable_mono_linux_x86_64/Godot_v4.7.2-stable_mono_linux.x86_64}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SMOKE_TICKS="${SMOKE_TICKS:-300}"

# Keep Godot's user-data writes inside the repo (sandbox/CI friendly).
export HOME="${GODOT_HOME:-$PROJECT_DIR/../.godot-home}"
mkdir -p "$HOME"

LOG_DIR="$PROJECT_DIR/../.test-logs"
mkdir -p "$LOG_DIR"

failures=0

echo "=== [1/2] Unit + integration suite ==="
"$GODOT" --headless --path "$PROJECT_DIR" res://tests/test_runner.tscn \
	> "$LOG_DIR/suite.log" 2>&1
suite_rc=$?
grep -E "All .* tests passed|tests failed" "$LOG_DIR/suite.log" | tail -1
errors=$(grep -c "SCRIPT ERROR" "$LOG_DIR/suite.log" || true)
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
"$GODOT" --headless --path "$PROJECT_DIR" res://game.tscn -- \
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
	echo "=== SUITE GREEN: unit tests passed, boot smoke passed, zero script errors ==="
	exit 0
else
	echo "=== SUITE RED: $failures check group(s) failed ==="
	exit 1
fi
