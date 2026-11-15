#!/usr/bin/env bash
# Scaffolds a new GOAP action from docs/ai/templates/action_template.gd.
#
#   ./tools/new_goap_action.sh FireArrow
#
# Creates goap/game_logic/actions/fire_arrow.gd and prints the remaining steps.
set -eu

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-}"

if [ -z "$NAME" ]; then
	echo "usage: $0 <PascalCaseActionName>   e.g. $0 FireArrow" >&2
	exit 2
fi
if ! printf '%s' "$NAME" | grep -Eq '^[A-Z][A-Za-z0-9]*$'; then
	echo "error: '$NAME' must be PascalCase (letters/digits, starting uppercase)" >&2
	exit 2
fi

SNAKE=$(printf '%s' "$NAME" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]')
DEST="$PROJECT_DIR/goap/game_logic/actions/${SNAKE}.gd"

if [ -e "$DEST" ]; then
	echo "error: $DEST already exists" >&2
	exit 1
fi

sed -e "s/MyAction/$NAME/g" -e "s/my_action/$SNAKE/g" \
	"$PROJECT_DIR/docs/ai/templates/action_template.gd" > "$DEST"

echo "created goap/game_logic/actions/${SNAKE}.gd"
echo "next steps:"
echo "  1. fill in the GOAP-GUIDE banner and the contract methods"
echo "  2. register it in goap/game_logic/action_registry.gd"
echo "  3. bump the registry count in tests/unit/test_planner_real_actions.gd"
echo "  4. ./tools/gen_goap_index.sh"
echo "  5. ./tests/run_goap_lint.sh   (then ./tests/run_suite.sh before committing)"
