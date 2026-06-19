#!/usr/bin/env bash
# Regression test for the 2026-02-13 role-confusion incident.
# Verifies every pane in v2 topology has the expected @agent_id.

set -euo pipefail

# Source constants to resolve session suffix
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${SCRIPT_DIR}/scripts/shutsujin_v2_constants.sh"
suffix="${SHOGUN_SESSION_SUFFIX:-}"

EXPECTED=(
    "multiagent${suffix}:ops.0:orchestrator"
    "multiagent${suffix}:ops.1:architect"
    "multiagent${suffix}:ops.2:experimentalist"
    "multiagent${suffix}:ops.3:analyst"
    "multiagent${suffix}:ops.4:ablation_planner"
    "multiagent${suffix}:research.0:surveyor"
    "multiagent${suffix}:research.1:critic"
    "multiagent${suffix}:research.2:writer"
    "multiagent${suffix}:research.3:observer"
    "multiagent${suffix}:research.4:council"
    "shogun${suffix}:main.0:shogun"
)

FAIL=0
for entry in "${EXPECTED[@]}"; do
    # entry is "session:window.pane:role"
    target="${entry%:*}"          # strip trailing ":role" → session:window.pane
    expected_role="${entry##*:}"  # last ":" and after → role

    session="${target%%:*}"       # session:window.pane → session
    sw="${target#*:}"             # session:window.pane → window.pane
    window="${sw%.*}"             # window.pane → window
    pane_idx="${sw##*.}"          # window.pane → pane

    actual=$(tmux list-panes -t "${session}:${window}" -F '#{@agent_id}' \
        | sed -n "$((pane_idx + 1))p")

    if [ "$actual" != "$expected_role" ]; then
        echo "FAIL: $target expected=$expected_role actual=$actual" >&2
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then
    echo "PASS: all 9 panes have expected @agent_id"
fi
exit $FAIL