#!/usr/bin/env bash
# scripts/import-workflow.sh
# Import version-controlled workflows into n8n (Linux / macOS / Oracle Cloud)
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

WORKFLOW_FILE="$PROJECT_ROOT/workflows/telegram_business_agent.json"
if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "Error: Workflow file not found at $WORKFLOW_FILE" >&2
  exit 1
fi

echo "Importing Phase 4 workflow into n8n..."
docker compose cp "$WORKFLOW_FILE" n8n:/tmp/telegram_business_agent.json
docker compose exec -T -u node n8n n8n import:workflow --input=/tmp/telegram_business_agent.json
docker compose exec -T -u node n8n rm -f /tmp/telegram_business_agent.json
echo "Workflow imported successfully!"
