#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# cleanup.sh — Tear down the v2 specialist-team tmux topology
#
# Kills the two sessions created by depart.sh so it can be re-run
# cleanly. Use this when:
#   - depart.sh's idempotency skips a config change (e.g. new CLI flag)
#   - pane layout/state is wedged
#   - you want a fresh start
#
# Pair with: cleanup.sh && ./depart.sh
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/scripts/shutsujin_v2_constants.sh" ]; then
    source "$SCRIPT_DIR/scripts/shutsujin_v2_constants.sh"
elif [ -f "$SCRIPT_DIR/shutsujin_v2_constants.sh" ]; then
    source "$SCRIPT_DIR/shutsujin_v2_constants.sh"
fi

SESSIONS=("shogun-research${SHOGUN_SESSION_SUFFIX:-}" "multiagent-research${SHOGUN_SESSION_SUFFIX:-}")

for s in "${SESSIONS[@]}"; do
    if tmux has-session -t "$s" 2>/dev/null; then
        tmux kill-session -t "$s"
        echo "[cleanup] killed session: $s"
    else
        echo "[cleanup] no session: $s (skipped)"
    fi
done
