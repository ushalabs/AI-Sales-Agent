#!/usr/bin/env bash
# scripts/init-tables.sh
# Initialize PostgreSQL tables for Telegram Business tracking (Linux / macOS / Oracle Cloud)
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

DB_USER="$(grep '^POSTGRES_USER=' .env | cut -d '=' -f2- | tr -d '\r')"
DB_NAME="$(grep '^POSTGRES_DB=' .env | cut -d '=' -f2- | tr -d '\r')"
DB_USER="${DB_USER:-n8n_db_user}"
DB_NAME="${DB_NAME:-n8n_sales_agent}"

echo "Creating Telegram Business tables in PostgreSQL..."
docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" < "$PROJECT_ROOT/scripts/init-db.sql"
echo "PostgreSQL tables initialized successfully."
