# AI Sales Agent - Database and Workflow Backup Script (Windows PowerShell)

$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$BackupDir = Join-Path $ProjectRoot "backups"
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$DbBackupFile = Join-Path $BackupDir "n8n_db_$Timestamp.sql"
$WorkflowBackupFile = Join-Path $ProjectRoot "workflows\workflows_$Timestamp.json"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting AI Sales Agent Backup ($Timestamp)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Backup PostgreSQL Database
Write-Host "[1/2] Creating PostgreSQL database backup..." -ForegroundColor Yellow
try {
    $EnvLines = Get-Content .env
    $DbUser = ($EnvLines | Where-Object { $_ -match '^POSTGRES_USER=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
    $DbName = ($EnvLines | Where-Object { $_ -match '^POSTGRES_DB=(.*)$' } | ForEach-Object { $matches[1] }).Trim()

    if (-not $DbUser) { $DbUser = "n8n_db_user" }
    if (-not $DbName) { $DbName = "n8n_sales_agent" }

    docker compose exec -T postgres pg_dump -U $DbUser $DbName > $DbBackupFile
    if ((Test-Path $DbBackupFile) -and ((Get-Item $DbBackupFile).Length -gt 0)) {
        Write-Host "PostgreSQL backup successfully saved: $DbBackupFile" -ForegroundColor Green
    } else {
        Write-Warning "Backup file was created but is empty. Check if postgres is running."
    }
}
catch {
    Write-Warning "Database backup failed: $_"
}

# 2. Export n8n Workflows
Write-Host "[2/2] Exporting n8n workflows..." -ForegroundColor Yellow
try {
    $exportOutput = docker compose exec -T -u node n8n n8n export:workflow --all --output=/tmp/workflows_export.json 2>&1
    if ($exportOutput -match "No workflows found") {
        Write-Host "No workflows currently exist in the n8n database to export." -ForegroundColor Yellow
    } else {
        docker compose cp n8n:/tmp/workflows_export.json $WorkflowBackupFile 2>$null
        docker compose exec -T -u node n8n rm -f /tmp/workflows_export.json 2>$null
        if (Test-Path $WorkflowBackupFile) {
            Write-Host "Workflows successfully exported to: $WorkflowBackupFile" -ForegroundColor Green
        }
    }
}
catch {
    Write-Warning "Workflow export failed: $_"
}

Write-Host "Backup process completed." -ForegroundColor Cyan
