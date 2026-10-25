# scripts/start-local.ps1
# AI Sales Agent - Local Development Stack Startup Script

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  STARTING AI SALES AGENT (LOCAL ENVIRONMENT)     " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Environment Check
if (-not (Test-Path .env)) {
    Write-Warning ".env file not found. Initializing from .env.example..."
    Copy-Item .env.example .env
}

# 2. Launch Local Containers
Write-Host "`n[1/4] Starting local Docker containers..." -ForegroundColor Yellow
docker compose up -d postgres n8n webhook_proxy

# 3. Wait for Health Checks
Write-Host "[2/4] Waiting for services to become healthy..." -ForegroundColor Yellow
$maxRetries = 25
$retry = 0
$healthy = $false

while (-not $healthy -and $retry -lt $maxRetries) {
    Start-Sleep -Seconds 2
    $retry++
    $pgStatus = docker inspect --format='{{json .State.Health.Status}}' sales_agent_postgres 2>$null
    $n8nStatus = docker inspect --format='{{json .State.Health.Status}}' sales_agent_n8n 2>$null
    
    if ($pgStatus -match "healthy" -and $n8nStatus -match "healthy") {
        $healthy = $true
        Write-Host "Services are healthy! (Postgres: $pgStatus, n8n: $n8nStatus)" -ForegroundColor Green
    }
}

if (-not $healthy) {
    Write-Error "Services failed to become healthy in time. Check: docker compose ps"
    exit 1
}

# 4. Apply Schema Enhancements
Write-Host "`n[3/5] Ensuring database tables and indexes exist..." -ForegroundColor Yellow
Get-Content "$ProjectRoot\scripts\enhance-database.sql" | docker compose exec -T postgres psql -U n8n_db_user -d n8n_sales_agent

# 5. Ensure Credentials
Write-Host "`n[4/5] Ensuring n8n credentials exist..." -ForegroundColor Yellow
& "$ProjectRoot\scripts\setup-credentials.ps1"

# 6. Import Workflows into n8n
Write-Host "`n[5/5] Importing updated workflows into n8n..." -ForegroundColor Yellow
$workflows = @(
    "telegram_business_agent.json",
    "subworkflow_owner_controls.json",
    "subworkflow_knowledge_retrieval.json",
    "subworkflow_gemini_agent.json",
    "sync_google_sheets.json"
)

foreach ($wf in $workflows) {
    $filePath = "$ProjectRoot\workflows\$wf"
    if (Test-Path $filePath) {
        docker cp $filePath "sales_agent_n8n:/tmp/$wf"
        docker compose exec -T -u node n8n n8n import:workflow --input="/tmp/$wf" | Out-Null
        docker compose exec -T -u 0 n8n rm -f "/tmp/$wf"
        Write-Host "  Imported: $wf" -ForegroundColor Green
    }
}

# Ensure all workflows are active and published
Write-Host "`nPublishing active workflows and refreshing n8n..." -ForegroundColor Yellow
$workflowIds = @("ktvkVp0E0z2blc4n", "0cGbWSPG0Z14h3So", "wMZ3vsdPji1oSAr0", "GzGhjXdy38xmzByE", "eSF3SSYCgDMeJQmR")
foreach ($id in $workflowIds) {
    docker compose exec -T -u node n8n n8n publish:workflow --id=$id | Out-Null
}
docker compose exec -T postgres psql -U n8n_db_user -d n8n_sales_agent -c "UPDATE workflow_entity SET active = true;" | Out-Null
docker compose restart n8n | Out-Null
Start-Sleep -Seconds 4

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  LOCAL DEVELOPMENT STACK IS READY!               " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "• n8n Editor:          http://localhost:5678"
Write-Host "• Webhook Endpoint:    http://localhost:5678/webhook/telegram-business"
Write-Host "• Simulator Mode:      ENABLED"
Write-Host "• Database:            PostgreSQL (persistent volume)"
Write-Host "==================================================" -ForegroundColor Cyan
