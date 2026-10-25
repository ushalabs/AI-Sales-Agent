# scripts/init-tables.ps1
# Initialize PostgreSQL tables for Telegram Business tracking

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$sqlFile = Join-Path $ProjectRoot "scripts\init-db.sql"
if (-not (Test-Path $sqlFile)) {
    Write-Error "init-db.sql not found!"
    exit 1
}

$EnvLines = Get-Content .env
$dbUser = ($EnvLines | Where-Object { $_ -match '^POSTGRES_USER=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$dbName = ($EnvLines | Where-Object { $_ -match '^POSTGRES_DB=(.*)$' } | ForEach-Object { $matches[1] }).Trim()

if (-not $dbUser) { $dbUser = "n8n_db_user" }
if (-not $dbName) { $dbName = "n8n_sales_agent" }

Write-Host "Creating Telegram Business tables in PostgreSQL..." -ForegroundColor Cyan
Get-Content $sqlFile | docker compose exec -T postgres psql -U $dbUser -d $dbName

Write-Host "PostgreSQL tables initialized successfully." -ForegroundColor Green
