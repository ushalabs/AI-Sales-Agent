#!/usr/bin/env bash
# scripts/register-webhook.sh
# Register and verify Telegram Webhook for Business Events (Linux / macOS / Oracle Cloud)
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

if [ ! -f .env ]; then
  echo "Error: .env file not found!" >&2
  exit 1
fi

BOT_TOKEN="$(grep '^TELEGRAM_BOT_TOKEN=' .env | cut -d '=' -f2- | tr -d '\r')"
WEBHOOK_URL="$(grep '^WEBHOOK_URL=' .env | cut -d '=' -f2- | tr -d '\r')"
SECRET_TOKEN="$(grep '^TELEGRAM_WEBHOOK_SECRET=' .env | cut -d '=' -f2- | tr -d '\r')"

if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "your_telegram_bot_token_here" ]; then
  echo "Error: TELEGRAM_BOT_TOKEN is not configured in .env!" >&2
  exit 1
fi

if [[ "$WEBHOOK_URL" =~ 127\.0\.0\.1 ]] || [[ "$WEBHOOK_URL" =~ localhost ]]; then
  echo "Error: WEBHOOK_URL points to localhost ($WEBHOOK_URL). A public HTTPS URL is required." >&2
  exit 1
fi

FULL_WEBHOOK_URL="${WEBHOOK_URL%/}/webhook/telegram-business"

echo "Registering Telegram Webhook..."
echo "Target URL: $FULL_WEBHOOK_URL"

PAYLOAD=$(cat <<EOF
{
  "url": "$FULL_WEBHOOK_URL",
  "allowed_updates": ["business_connection", "business_message", "edited_business_message", "message"],
  "drop_pending_updates": true,
  "secret_token": "$SECRET_TOKEN"
}
EOF
)

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | grep -q '"ok":true' && echo "Telegram Webhook successfully set!" || echo "Failed to set webhook"

echo "Checking Webhook Info..."
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"
