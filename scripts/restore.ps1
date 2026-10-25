# scripts/restore.ps1
# AI Sales Agent - Database Restore Script (Windows PowerShell)
param (
    [Parameter(Mandatory=$false)]
    [string]$BackupFile
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not $BackupFile) {
    Write-Host "Usage: .\scripts\restore.ps1 -BackupFile <path_to_backup.sql>" -ForegroundColor Yellow
    Write-Host "Available backups in backups\:" -ForegroundColor Cyan
    Get-ChildItem -Path "$ProjectRoot\backups\*.sql" -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime | Format-Table
    exit 1
}

if (-not (Test-Path $BackupFile)) {
    Write-Error "Backup file not found: $BackupFile"
    exit 1
}

$EnvLines = Get-Content .env
$dbUser = ($EnvLines | Where-Object { $_ -match '^POSTGRES_USER=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$dbName = ($EnvLines | Where-Object { $_ -match '^POSTGRES_DB=(.*)$' } | ForEach-Object { $matches[1] }).Trim()

if (-not $dbUser) { $dbUser = "n8n_db_user" }
if (-not $dbName) { $dbName = "n8n_sales_agent" }

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " RESTORING POSTGRESQL DATABASE FROM BACKUP        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "File:     $BackupFile"
Write-Host "Database: $dbName"
Write-Host "User:     $dbUser"

Get-Content $BackupFile | docker compose exec -T postgres psql -U $dbUser -d $dbName

Write-Host "Restore successfully completed." -ForegroundColor Green
