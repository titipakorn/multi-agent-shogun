#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# shogun_stop_telegram_forward.sh — Claude Code Stop Hook
# Stops background telegram/ntfy processes on session stop.
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Kill telegram listener if pid file exists
if [ -f "$SCRIPT_DIR/logs/listener.pid" ]; then
    PID=$(cat "$SCRIPT_DIR/logs/listener.pid")
    if [ -n "$PID" ]; then
        kill "$PID" 2>/dev/null || true
    fi
    rm -f "$SCRIPT_DIR/logs/listener.pid"
fi

# Broad cleanup for background scripts of this project
pkill -f "telegram_listener.py" 2>/dev/null || true
pkill -f "shogun_telegram_relay.sh" 2>/dev/null || true
pkill -f "listener_watchdog.sh" 2>/dev/null || true
pkill -f "ntfy_listener.sh" 2>/dev/null || true

exit 0
