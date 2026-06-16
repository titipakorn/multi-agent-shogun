#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# setup.sh - Wrapper script for compatibility
# ═══════════════════════════════════════════════════════════════════════════════
# This script has been merged into depart.sh.
# For compatibility, all arguments are forwarded to depart.sh.
#
# Recommendation: Use ./depart.sh directly.
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/depart.sh" "$@"
