#!/usr/bin/env bash
# ==============================================================================
# AI Sales Agent - Database and Workflow Restore Script (Linux / macOS / Oracle Cloud)
# ==============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

if [ -z "$1" ]; then
    echo "Usage: ./scripts/restore.sh <path_to_backup.sql>"
    echo "Example: ./scripts/restore.sh backups/n8n_db_20261025_120000.sql"
    echo ""
    echo "Available SQL backups in backups/:"
    ls -lh "$PROJECT_ROOT/backups"/*.sql 2>/dev/null || echo "  (None found)"
    exit 1
fi

BACKUP_FILE="$1"
if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file '$BACKUP_FILE' does not exist."
    exit 1
fi

# Load DB settings
if [ -f .env.production ]; then
    # shellcheck disable=SC1091
    source .env.production
elif [ -f .env ]; then
    # shellcheck disable=SC1091
    source .env
fi

DB_USER="${POSTGRES_USER:-n8n_db_user}"
DB_NAME="${POSTGRES_DB:-n8n_sales_agent}"

COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.prod.yml" ] && [ -f ".env.production" ]; then
    COMPOSE_FILE="docker-compose.prod.yml"
fi

echo "=================================================================="
echo "    RESTORING POSTGRESQL DATABASE FROM BACKUP                    "
echo "=================================================================="
echo "Backup File: $BACKUP_FILE"
echo "Database:    $DB_NAME"
echo "User:        $DB_USER"
echo "Compose:     $COMPOSE_FILE"
echo "=================================================================="

echo "Applying SQL restore to PostgreSQL container..."
docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_FILE"

echo "Database restore completed successfully."
