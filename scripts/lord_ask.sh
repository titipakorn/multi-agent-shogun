#!/usr/bin/env bash
# lord_ask.sh — AskQuestion → Telegram wrapper.
#
# Usage:
#   lord_ask.sh <question> [option1 option2 ...] [--timeout <seconds>]
#
# Behavior:
#   1. Generates a request_id.
#   2. Calls telegram_ask.py to send the question to Telegram and write
#      queue/current_question.json.
#   3. Polls current_question.json every 1 s for status=answered.
#   4. On success: prints the answer to stdout, clears the file, exits 0.
#   5. On timeout: prints "no answer; proceeding with default", emits a
#      lord_question_timeout event into queue/inbox/shogun.yaml, exits 3.
#   6. On Telegram not configured: prints message to stderr, exits 2.
#
# Test overrides:
#   LORD_ASK_PYTHON     — path to telegram_ask.py (default: $SCRIPT_DIR/telegram_ask.py)
#   LORD_ASK_QUEUE_DIR  — path to queue dir   (default: $SCRIPT_DIR/../queue)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEGRAM_ASK="${LORD_ASK_PYTHON:-$SCRIPT_DIR/telegram_ask.py}"
QUEUE_DIR="${LORD_ASK_QUEUE_DIR:-$SCRIPT_DIR/../queue}"
QUESTION_FILE="$QUEUE_DIR/current_question.json"
TIMEOUT="${LORD_ASK_TIMEOUT:-86400}"
INBOX_FILE="$QUEUE_DIR/inbox/shogun.yaml"
mkdir -p "$(dirname "$INBOX_FILE")"

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" \
      || "$TELEGRAM_BOT_TOKEN" == "your_bot_token_here" \
      || "$TELEGRAM_CHAT_ID" == "your_chat_id_here" ]]; then
    echo "Telegram not configured — falling back to terminal." >&2
    exit 2
fi

# Parse args
QUESTION=""
OPTIONS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        *) if [[ -z "$QUESTION" ]]; then QUESTION="$1"; else OPTIONS+=("$1"); fi; shift ;;
    esac
done

if [[ -z "$QUESTION" ]]; then
    echo "Usage: lord_ask.sh <question> [options] [--timeout <s>]" >&2
    exit 64
fi

REQUEST_ID="$(date +%s)-$(printf '%04x' $RANDOM)"

# Build telegram_ask.py args
ASK_ARGS=(--question "$QUESTION" --question-file "$QUESTION_FILE"
          --chat-id "$TELEGRAM_CHAT_ID" --token "$TELEGRAM_BOT_TOKEN"
          --timeout "$TIMEOUT" --no-wait)
for o in "${OPTIONS[@]:-}"; do
    ASK_ARGS+=(--options "$o")
done

REQUEST_ID="$REQUEST_ID" python3 "$TELEGRAM_ASK" "${ASK_ARGS[@]}" \
    || { echo "ERROR: telegram_ask.py failed" >&2; exit 1; }

# Poll
START=$(date +%s)
while true; do
    NOW=$(date +%s)
    if [[ $((NOW - START)) -ge $TIMEOUT ]]; then
        echo "no answer; proceeding with default assumption"
        # Emit event to shogun inbox
        TS=$(date -Iseconds)
        printf -- '- id: %s\n  from: lord_ask\n  type: lord_question_timeout\n  timestamp: "%s"\n  read: false\n  question: "%s"\n' \
            "$REQUEST_ID" "$TS" "${QUESTION//\"/\\\"}" >> "$INBOX_FILE"
        exit 3
    fi
    if [[ -f "$QUESTION_FILE" ]]; then
        STATUS=$(python3 -c "import json; print(json.load(open('$QUESTION_FILE')).get('status',''))" 2>/dev/null || echo "")
        if [[ "$STATUS" == "answered" ]]; then
            ANSWER=$(python3 -c "import json; print(json.load(open('$QUESTION_FILE')).get('response',''))" 2>/dev/null || echo "")
            rm -f "$QUESTION_FILE"
            printf '%s' "$ANSWER"
            exit 0
        fi
    fi
    sleep 1
done
