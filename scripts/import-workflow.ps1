# scripts/import-workflow.ps1
# Import version-controlled workflows into n8n

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$workflowFile = Join-Path $ProjectRoot "workflows\telegram_business_agent.json"
if (-not (Test-Path $workflowFile)) {
    Write-Error "Workflow file not found at $workflowFile"
    exit 1
}

Write-Host "Importing Phase 4 workflow into n8n..." -ForegroundColor Cyan

docker compose cp $workflowFile n8n:/tmp/telegram_business_agent.json
docker compose exec -T -u node n8n n8n import:workflow --input=/tmp/telegram_business_agent.json
docker compose exec -T -u node n8n rm -f /tmp/telegram_business_agent.json

Write-Host "Workflow imported successfully!" -ForegroundColor Green
