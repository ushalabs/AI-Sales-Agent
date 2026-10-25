# scripts/stop-local.ps1
# AI Sales Agent - Local Development Stack Stop Script

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  STOPPING AI SALES AGENT (LOCAL ENVIRONMENT)     " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Stop containers without removing persistent volumes
docker compose down

Write-Host "`nAll local containers have been safely stopped." -ForegroundColor Green
Write-Host "NOTE: All database records, saved workflows, and credentials remain safely persisted in Docker volumes." -ForegroundColor Gray
