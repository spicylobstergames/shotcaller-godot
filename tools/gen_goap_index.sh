#!/usr/bin/env bash
# Regenerates docs/ai/goap-index.md from the GOAP-GUIDE banners.
#
#   ./tools/gen_goap_index.sh [godot-binary]
#
# Godot binary resolution: argument > GODOT env var > "godot" on PATH.
# Run this whenever you add/rename an action or goal, or edit a banner.
set -u

GODOT="${1:-${GODOT:-godot}}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export HOME="${GODOT_HOME:-$PROJECT_DIR/../.godot-home}"
mkdir -p "$HOME"

timeout "${STEP_TIMEOUT:-120}" "$GODOT" --headless --path "$PROJECT_DIR" \
	res://tests/test_runner.tscn -- --gen-goap-index
