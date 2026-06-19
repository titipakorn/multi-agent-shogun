#!/usr/bin/env bash
# Verifies pane count per window in v2 topology.
# Expected: 4 panes in ops, 4 in research, 1 in shogun.

set -euo pipefail

# Source constants to resolve session suffix
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${SCRIPT_DIR}/scripts/shutsujin_v2_constants.sh"
suffix="${SHOGUN_SESSION_SUFFIX:-}"

OPS_COUNT=$(tmux list-panes -t "multiagent${suffix}:ops" | wc -l | tr -d ' ')
RESEARCH_COUNT=$(tmux list-panes -t "multiagent${suffix}:research" | wc -l | tr -d ' ')
SHOGUN_COUNT=$(tmux list-panes -t "shogun${suffix}:main" | wc -l | tr -d ' ')

FAIL=0
[ "$OPS_COUNT" -eq 5 ] || {
    echo "FAIL: ops has $OPS_COUNT panes (expected 5)" >&2
    echo "  HINT: shut down the v2 session (tmux kill-session -t multiagent) and rerun" >&2
    FAIL=1
}
[ "$RESEARCH_COUNT" -eq 5 ] || {
    echo "FAIL: research has $RESEARCH_COUNT panes (expected 5)" >&2
    FAIL=1
}
[ "$SHOGUN_COUNT" -eq 1 ] || {
    echo "FAIL: shogun has $SHOGUN_COUNT panes (expected 1)" >&2
    FAIL=1
}

if [ "$FAIL" -eq 0 ]; then
    echo "PASS: 5 panes in ops, 5 in research, 1 in shogun"
fi
exit $FAIL