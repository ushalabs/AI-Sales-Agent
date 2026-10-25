#!/usr/bin/env bash
# ==============================================================================
# AI Sales Agent - Production Connectivity and Health Verification Script
# ==============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

ENV_PROD="$PROJECT_ROOT/.env.production"
if [ ! -f "$ENV_PROD" ]; then
    ENV_PROD="$PROJECT_ROOT/.env"
fi

if [ -f "$ENV_PROD" ]; then
    # shellcheck disable=SC1090
    source "$ENV_PROD"
fi

echo "=================================================================="
echo "    ORACLE CLOUD PRODUCTION CONNECTIVITY & INTEGRATION CHECK      "
echo "=================================================================="

# 1. Telegram Bot API Connectivity Check
echo -n "[1/5] Checking outbound Telegram Bot API connectivity... "
TG_RESP=$(curl -s -m 10 "https://api.telegram.org" 2>&1 || true)
if [[ "$TG_RESP" == *"ok"* ]] || [[ "$TG_RESP" == *"Unauthorized"* ]] || [[ "$TG_RESP" == *"error"* ]] || [[ "$TG_RESP" == *"Bad Request"* ]] || [[ "$TG_RESP" == *"404"* ]]; then
    echo "SUCCESS (api.telegram.org is reachable)"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [[ "$TELEGRAM_BOT_TOKEN" != *"YOUR_"* ]]; then
        ME_CHECK=$(curl -s -m 10 "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" || true)
        if [[ "$ME_CHECK" == *"\"ok\":true"* ]]; then
            BOT_NAME=$(echo "$ME_CHECK" | grep -o '"username":"[^"]*"' | cut -d':' -f2 | tr -d '"')
            echo "      Telegram Bot Verified: @$BOT_NAME"
        else
            echo "      Warning: Bot token returned: $ME_CHECK"
        fi
    fi
else
    echo "FAILED! Outbound connection to api.telegram.org timed out or was blocked."
    echo "Response: $TG_RESP"
fi

# 2. Gemini AI API Connectivity Check
echo -n "[2/5] Checking outbound Google Gemini API connectivity... "
GEMINI_RESP=$(curl -s -m 10 "https://generativelanguage.googleapis.com" 2>&1 || true)
if [[ "$GEMINI_RESP" == *"404"* ]] || [[ "$GEMINI_RESP" == *"Method Not Allowed"* ]] || [[ "$GEMINI_RESP" == *"Google"* ]]; then
    echo "SUCCESS (generativelanguage.googleapis.com is reachable)"
else
    echo "FAILED! Outbound connection to Gemini API timed out."
fi

# 3. Google Sheets Connectivity Check
echo -n "[3/5] Checking outbound Google Sheets API connectivity... "
SHEETS_RESP=$(curl -s -m 10 "https://sheets.googleapis.com" 2>&1 || true)
if [[ "$SHEETS_RESP" == *"404"* ]] || [[ "$SHEETS_RESP" == *"Method Not Allowed"* ]] || [[ "$SHEETS_RESP" == *"Google"* ]]; then
    echo "SUCCESS (sheets.googleapis.com is reachable)"
else
    echo "FAILED! Outbound connection to Google Sheets API timed out."
fi

# 4. Public Webhook & Reverse Proxy Check
echo -n "[4/5] Checking inbound HTTPS domain & webhook route... "
if [ -n "$DOMAIN_NAME" ] && [ "$DOMAIN_NAME" != "agent.yourdomain.com" ]; then
    WEBHOOK_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "https://${DOMAIN_NAME}/webhook/telegram-business-sales-agent" 2>&1 || true)
    ROOT_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "https://${DOMAIN_NAME}/" 2>&1 || true)
    
    echo "Public Domain: https://${DOMAIN_NAME}"
    echo "      Root (Admin protection): HTTP $ROOT_CODE (Expected 403)"
    echo "      Webhook Endpoint: HTTP $WEBHOOK_CODE"
    if [ "$ROOT_CODE" == "403" ]; then
        echo "      Security Policy: ENFORCED (Admin UI blocked from public internet)"
    fi
else
    echo "SKIPPED (DOMAIN_NAME is not set or using placeholder)"
fi

# 5. Local Docker Container Statuses
echo "[5/5] Docker Container Health Statuses:"
docker compose -f docker-compose.prod.yml ps 2>/dev/null || docker compose ps

echo "=================================================================="
echo "    CONNECTIVITY CHECK COMPLETED                                  "
echo "=================================================================="
