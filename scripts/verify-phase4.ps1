# scripts/verify-phase4.ps1
# Phase 4 Consolidated Verification Suite

$ErrorActionPreference = "Continue"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " AI SALES AGENT - PHASE 4 VERIFICATION SUITE      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$allPassed = $true

# 1. Check Docker Services Status
Write-Host "`n[Check 1/6] Inspecting Docker Compose Services..." -ForegroundColor Yellow
$psOutput = docker compose ps --format json | ConvertFrom-Json
$services = @("postgres", "n8n", "webhook_proxy", "cloudflared")

foreach ($svc in $services) {
    $container = $psOutput | Where-Object { $_.Service -eq $svc }
    if ($container -and $container.State -eq "running") {
        $healthStr = if ($container.Health) { $container.Health } else { "running" }
        Write-Host "  Service $svc : RUNNING ($healthStr)" -ForegroundColor Green
    } else {
        $stateStr = if ($container) { $container.State } else { "not created" }
        Write-Host "  Service $svc : NOT RUNNING (State: $stateStr)" -ForegroundColor Red
        $allPassed = $false
    }
}

# 2. Check Database Tables
Write-Host "`n[Check 2/6] Verifying PostgreSQL Tables for State Tracking & Deduplication..." -ForegroundColor Yellow
$tablesCheck = docker compose exec -T postgres psql -U n8n_db_user -d n8n_sales_agent -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('telegram_processed_updates', 'telegram_business_connections');"
$hasUpdatesTable = $tablesCheck -match "telegram_processed_updates"
$hasConnectionsTable = $tablesCheck -match "telegram_business_connections"

$upColor = if ($hasUpdatesTable) { "Green" } else { "Red" }
$connColor = if ($hasConnectionsTable) { "Green" } else { "Red" }
Write-Host "  telegram_processed_updates table:    $hasUpdatesTable" -ForegroundColor $upColor
Write-Host "  telegram_business_connections table: $hasConnectionsTable" -ForegroundColor $connColor
if (-not $hasUpdatesTable -or -not $hasConnectionsTable) { $allPassed = $false }

# 3. Check Proxy Route Isolation (Security Verification)
Write-Host "`n[Check 3/6] Verifying Webhook Proxy Route Isolation & Security..." -ForegroundColor Yellow
$rootProbe = docker compose exec -T n8n node -e "fetch('http://webhook_proxy/').then(r => console.log(r.status))" 2>&1
$isBlocked = $rootProbe -match "403"
$blockColor = if ($isBlocked) { "Green" } else { "Red" }
Write-Host "  Direct root access / blocked with 403 Forbidden: $isBlocked" -ForegroundColor $blockColor
if (-not $isBlocked) { $allPassed = $false }

# 4. Check Cloudflare Quick Tunnel
Write-Host "`n[Check 4/6] Verifying Cloudflare Quick Tunnel..." -ForegroundColor Yellow
$tunnelUrl = (docker compose logs cloudflared 2>&1 | Select-String -Pattern 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' | ForEach-Object { $_.Matches.Value } | Select-Object -First 1)

if ($tunnelUrl) {
    Write-Host "  Active Public Tunnel URL: $tunnelUrl" -ForegroundColor Green
} else {
    Write-Host "  Could not find active trycloudflare.com URL in cloudflared logs." -ForegroundColor Red
    $allPassed = $false
}

# 5. Check Environment & Safety Settings
Write-Host "`n[Check 5/6] Checking Telegram Safety Configuration..." -ForegroundColor Yellow
$envLines = Get-Content .env
$testMode = ($envLines | Where-Object { $_ -match '^TELEGRAM_TEST_MODE=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$sellerId = ($envLines | Where-Object { $_ -match '^TELEGRAM_SELLER_USER_ID=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$allowlist = ($envLines | Where-Object { $_ -match '^TELEGRAM_ALLOWED_TEST_CHAT_IDS=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$botTokenVal = ($envLines | Where-Object { $_ -match '^TELEGRAM_BOT_TOKEN=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$botTokenSet = (-not [string]::IsNullOrWhiteSpace($botTokenVal)) -and ($botTokenVal -notlike "*replace*") -and ($botTokenVal -notlike "*your_*")

$modeColor = if ($testMode -eq "true") { "Yellow" } else { "Green" }
Write-Host "  Safety Switch (TELEGRAM_TEST_MODE): $testMode" -ForegroundColor $modeColor
Write-Host "  Seller User ID Configured:          $(if ($sellerId) { 'YES' } else { 'PENDING (Set in .env)' })"
Write-Host "  Authorized Test Chat IDs:           $(if ($allowlist) { $allowlist } else { 'EMPTY (Default Safe)' })"
Write-Host "  Bot Token Configured in .env:       $(if ($botTokenSet) { 'YES' } else { 'PENDING (Set in .env)' })"

# 6. Check Local & Public Webhook Reachability
Write-Host "`n[Check 6/6] Verifying Webhook Path Reachability..." -ForegroundColor Yellow
$localProbe = (docker compose exec -T n8n node -e "fetch('http://127.0.0.1:5678/webhook/telegram-business', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ update_id: 1001 }) }).then(r => console.log(r.status))" 2>&1).Trim()
$isLocalOk = $localProbe -eq "200"
$localColor = if ($isLocalOk) { "Green" } else { "Red" }
Write-Host "  Local Webhook Endpoint Status:     $localProbe" -ForegroundColor $localColor
if (-not $isLocalOk) { $allPassed = $false }

if ($tunnelUrl) {
    $publicProbe = (docker compose exec -T n8n node -e "fetch('$tunnelUrl/webhook/telegram-business', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ update_id: 1002 }) }).then(r => console.log(r.status))" 2>&1).Trim()
    $isPublicOk = $publicProbe -eq "200"
    $publicColor = if ($isPublicOk) { "Green" } else { "Red" }
    Write-Host "  Public Tunnel Webhook Status:      $publicProbe" -ForegroundColor $publicColor
    if (-not $isPublicOk) { $allPassed = $false }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host " ALL PHASE 4 INFRASTRUCTURE CHECKS PASSED!        " -ForegroundColor Green
} else {
    Write-Host " SOME CHECKS REQUIRE ATTENTION (See above)        " -ForegroundColor Yellow
}
Write-Host "==================================================" -ForegroundColor Cyan
