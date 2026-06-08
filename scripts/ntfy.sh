#!/usr/bin/env bash
# SayTask Notification — Send push notification to smartphone via ntfy.sh
# FR-066: ntfy authentication support (Bearer token / Basic auth)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$SCRIPT_DIR/config/settings.yaml"

# Load Telegram configuration if available
TELEGRAM_ENV="$SCRIPT_DIR/config/telegram.env"
if [ -f "$TELEGRAM_ENV" ]; then
  # Sourcing the env file
  # shellcheck disable=SC1090
  source "$TELEGRAM_ENV"
fi

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ] && [ "$TELEGRAM_BOT_TOKEN" != "your_bot_token_here" ]; then
  # Route notification to Telegram
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${1}" > /dev/null
  exit 0
fi

# Fallback to ntfy if Telegram is not configured
# Load ntfy_auth.sh
# shellcheck source=../lib/ntfy_auth.sh
source "$SCRIPT_DIR/lib/ntfy_auth.sh"

TOPIC=$(grep 'ntfy_topic:' "$SETTINGS" 2>/dev/null | awk '{print $2}' | tr -d '"')
if [ -z "$TOPIC" ]; then
  # Silently exit if neither Telegram nor ntfy is configured to prevent error noise
  exit 0
fi

# Get auth args (empty if no settings = backward compatibility)
AUTH_ARGS=()
while IFS= read -r line; do
    [ -n "$line" ] && AUTH_ARGS+=("$line")
done < <(ntfy_get_auth_args "$SCRIPT_DIR/config/ntfy_auth.env")

# shellcheck disable=SC2086
curl -s "${AUTH_ARGS[@]}" -H "Tags: outbound" -d "$1" "https://ntfy.sh/$TOPIC" > /dev/null
