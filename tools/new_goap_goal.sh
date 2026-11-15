#!/usr/bin/env bash
# Scaffolds a new GOAP goal from docs/ai/templates/goal_template.gd.
#
#   ./tools/new_goap_goal.sh HoldGround
#
# Creates goap/game_logic/goals/hold_ground.gd and prints the remaining steps.
set -eu

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-}"

if [ -z "$NAME" ]; then
	echo "usage: $0 <PascalCaseGoalName>   e.g. $0 HoldGround" >&2
	exit 2
fi
if ! printf '%s' "$NAME" | grep -Eq '^[A-Z][A-Za-z0-9]*$'; then
	echo "error: '$NAME' must be PascalCase (letters/digits, starting uppercase)" >&2
	exit 2
fi

SNAKE=$(printf '%s' "$NAME" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]')
DEST="$PROJECT_DIR/goap/game_logic/goals/${SNAKE}.gd"

if [ -e "$DEST" ]; then
	echo "error: $DEST already exists" >&2
	exit 1
fi

sed -e "s/MyGoal/$NAME/g" -e "s/my_goal/$SNAKE/g" \
	"$PROJECT_DIR/docs/ai/templates/goal_template.gd" > "$DEST"

echo "created goap/game_logic/goals/${SNAKE}.gd"
echo "next steps:"
echo "  1. fill in the GOAP-GUIDE banner and the goal contract"
echo "  2. register it in goap/game_logic/goal_registry.gd"
echo "  3. add its name to the goals_list of the unit scenes that should use it"
echo "  4. ./tools/gen_goap_index.sh"
echo "  5. ./tests/run_goap_lint.sh   (then ./tests/run_suite.sh before committing)"
