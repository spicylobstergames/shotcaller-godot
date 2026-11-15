#!/usr/bin/env bash
# Re-records the golden replay checkpoints (tests/golden/replay_<frames>.txt).
#
#   ./tests/record_golden.sh [godot-binary]
#
# ONLY do this for a behavior change you INTEND, and state the reason in the
# commit message (DECISIONS.md D6/D12). Never re-record to make a real
# regression disappear — the point of the replay is that divergence is loud.
set -u

GODOT="${1:-${GODOT:-godot}}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export HOME="${GODOT_HOME:-$PROJECT_DIR/../.godot-home}"
mkdir -p "$HOME"
LOG_DIR="${TEST_LOG_DIR:-$PROJECT_DIR/../.test-logs}"
mkdir -p "$LOG_DIR"
SMOKE_TICKS="${SMOKE_TICKS:-300}"

timeout "${STEP_TIMEOUT:-180}" "$GODOT" --headless --fixed-fps 60 --path "$PROJECT_DIR" res://game.tscn -- \
	--smoke --golden --golden-update --smoke-ticks="$SMOKE_TICKS" \
	> "$LOG_DIR/golden-update.log" 2>&1
rc=$?

grep -E "GOLDEN_UPDATED|GOLDEN_OK|GOLDEN_FAILED" "$LOG_DIR/golden-update.log" || tail -20 "$LOG_DIR/golden-update.log"
errors=$(grep -c "SCRIPT ERROR" "$LOG_DIR/golden-update.log" || true)
if [ "$rc" -ne 0 ] || [ "$errors" -gt 0 ]; then
	echo "GOLDEN RE-RECORD FAILED (rc=$rc, script errors=$errors) — see $LOG_DIR/golden-update.log"
	exit 1
fi

echo "--- golden diff ---"
git -C "$PROJECT_DIR" --no-pager diff --stat -- tests/golden/ || true
echo "Re-recorded. Confirm the diff is exactly the intended change, then commit with the reason."
