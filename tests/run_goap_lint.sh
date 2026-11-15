#!/usr/bin/env bash
# Fast GOAP-only gate: script parse + planner + state-key/contract lint.
# Intended for tight iteration while editing the AI; run_suite.sh remains the
# definition of done (it adds the boot smoke, golden replay, and the pinned
# assertion count).
#
#   ./tests/run_goap_lint.sh [godot-binary]
#
# Godot binary resolution: argument > GODOT env var > "godot" on PATH.
# TEST_LOG_DIR overrides where the log is written (default: $PROJECT_DIR/../.test-logs).
set -u

GODOT="${1:-${GODOT:-godot}}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export HOME="${GODOT_HOME:-$PROJECT_DIR/../.godot-home}"
mkdir -p "$HOME"
LOG_DIR="${TEST_LOG_DIR:-$PROJECT_DIR/../.test-logs}"
mkdir -p "$LOG_DIR"

ONLY="ScriptParse,Planner,PlannerRealActions,StateKeys,GoapContractLint,GoapIndex"

timeout "${STEP_TIMEOUT:-120}" "$GODOT" --headless --path "$PROJECT_DIR" \
	res://tests/test_runner.tscn -- "--only=$ONLY" \
	> "$LOG_DIR/goap_lint.log" 2>&1
rc=$?

grep -E "TESTS_COMPLETE|All .* tests passed" "$LOG_DIR/goap_lint.log" || tail -20 "$LOG_DIR/goap_lint.log"
errors=$(grep -c "SCRIPT ERROR" "$LOG_DIR/goap_lint.log" || true)
if [ "$rc" -ne 0 ] || [ "$errors" -gt 0 ]; then
	echo "GOAP LINT FAILED (rc=$rc, script errors=$errors) — see $LOG_DIR/goap_lint.log"
	grep "SCRIPT ERROR" "$LOG_DIR/goap_lint.log" | sort -u | head -10
	exit 1
fi
echo "GOAP LINT OK (parse + planner + state-key/contract lint)"
