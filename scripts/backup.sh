#!/usr/bin/env bash
# AI Sales Agent - Database and Workflow Backup Script (Linux / macOS / Oracle Cloud)
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

BACKUP_DIR="$PROJECT_ROOT/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
DB_BACKUP_FILE="$BACKUP_DIR/n8n_db_${TIMESTAMP}.sql"
WORKFLOW_BACKUP_FILE="$PROJECT_ROOT/workflows/workflows_${TIMESTAMP}.json"

echo "========================================"
echo "Starting AI Sales Agent Backup ($TIMESTAMP)"
echo "========================================"

# Read DB settings from .env
if [ -f .env ]; then
  # shellcheck disable=SC1091
  DB_USER="$(grep '^POSTGRES_USER=' .env | cut -d '=' -f2- | tr -d '\r')"
  DB_NAME="$(grep '^POSTGRES_DB=' .env | cut -d '=' -f2- | tr -d '\r')"
fi
DB_USER="${DB_USER:-n8n_db_user}"
DB_NAME="${DB_NAME:-n8n_sales_agent}"

# 1. Backup PostgreSQL Database
echo "[1/2] Creating PostgreSQL database backup..."
if docker compose exec -T postgres pg_dump -U "$DB_USER" "$DB_NAME" > "$DB_BACKUP_FILE"; then
  echo "PostgreSQL backup successfully saved: $DB_BACKUP_FILE"
else
  echo "Warning: Database backup failed. Ensure containers are running." >&2
fi

# 2. Export n8n Workflows
echo "[2/2] Exporting n8n workflows..."
EXPORT_LOG=$(docker compose exec -T -u node n8n n8n export:workflow --all --output=/tmp/workflows_export.json 2>&1 || true)
if echo "$EXPORT_LOG" | grep -q "No workflows found"; then
  echo "No workflows currently exist in the n8n database to export."
else
  docker compose cp n8n:/tmp/workflows_export.json "$WORKFLOW_BACKUP_FILE" 2>/dev/null || true
  docker compose exec -T -u node n8n rm -f /tmp/workflows_export.json 2>/dev/null || true
  if [ -f "$WORKFLOW_BACKUP_FILE" ]; then
    echo "Workflows exported to: $WORKFLOW_BACKUP_FILE"
  fi
fi

echo "Backup process completed."
