#!/usr/bin/env bash
# scripts/start-tunnel.sh
# Start Cloudflare Quick Tunnel and configure n8n WEBHOOK_URL (Linux / macOS / Oracle Cloud)
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "=================================================="
echo " STARTING CLOUDFLARE QUICK TUNNEL & WEBHOOK PROXY "
echo "=================================================="

echo "[1/4] Starting webhook_proxy and cloudflared containers..."
docker compose up -d webhook_proxy cloudflared

echo "[2/4] Waiting for Cloudflare Quick Tunnel assignment..."
TUNNEL_URL=""
for i in {1..25}; do
  sleep 2
  LOGS=$(docker compose logs cloudflared 2>&1 || true)
  TUNNEL_URL=$(echo "$LOGS" | grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' | head -n 1 || true)
  if [ -n "$TUNNEL_URL" ]; then
    break
  fi
done

if [ -z "$TUNNEL_URL" ]; then
  echo "Error: Could not obtain Cloudflare Tunnel URL. Check logs: docker compose logs cloudflared" >&2
  exit 1
fi

echo "Assigned Tunnel URL: $TUNNEL_URL"

echo "[3/4] Updating WEBHOOK_URL in .env..."
FORMATTED_URL="${TUNNEL_URL%/}/"
if grep -q '^WEBHOOK_URL=' .env; then
  sed -i "s|^WEBHOOK_URL=.*|WEBHOOK_URL=$FORMATTED_URL|" .env
else
  echo "WEBHOOK_URL=$FORMATTED_URL" >> .env
fi

echo "[4/4] Restarting n8n to apply configuration..."
docker compose up -d n8n

echo "=================================================="
echo " CLOUDFLARE TUNNEL INITIALIZATION COMPLETE!       "
echo "=================================================="
echo "Public Webhook URL: $TUNNEL_URL/webhook/telegram-business"
echo "Security:           Direct root access is blocked (403 Forbidden)"
echo "Local n8n Editor:   Accessible at http://127.0.0.1:5678"
