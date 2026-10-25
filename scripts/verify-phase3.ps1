# scripts/verify-phase3.ps1
# Phase 3 Consolidated End-of-Phase Verification Script

$ErrorActionPreference = "Continue"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " AI SALES AGENT - PHASE 3 VERIFICATION SUITE      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$allPassed = $true

# 1. Check Container Health & Status
Write-Host "`n[Check 1/6] Inspecting Docker Compose Services..." -ForegroundColor Yellow
$psOutput = docker compose ps --format json | ConvertFrom-Json
$pgContainer = $psOutput | Where-Object { $_.Service -eq "postgres" }
$n8nContainer = $psOutput | Where-Object { $_.Service -eq "n8n" }

$pgColor = if ($pgContainer.Health -eq "healthy") { "Green" } else { "Red" }
$n8nColor = if ($n8nContainer.Health -eq "healthy") { "Green" } else { "Yellow" }

Write-Host "PostgreSQL Status: $($pgContainer.State) ($($pgContainer.Health))" -ForegroundColor $pgColor
Write-Host "n8n Status:        $($n8nContainer.State) ($($n8nContainer.Health))" -ForegroundColor $n8nColor

if ($pgContainer.State -ne "running" -or $pgContainer.Health -ne "healthy") { $allPassed = $false }
if ($n8nContainer.State -ne "running" -or $n8nContainer.Health -ne "healthy") { $allPassed = $false }

# 2. Check PostgreSQL Health Directly
Write-Host "`n[Check 2/6] Querying PostgreSQL Health Directly..." -ForegroundColor Yellow
$pgReady = docker compose exec -T postgres pg_isready -U n8n_db_user -d n8n_sales_agent
Write-Host "$pgReady"
if ($LASTEXITCODE -eq 0) {
    Write-Host "PostgreSQL is accepting connections." -ForegroundColor Green
} else {
    Write-Host "PostgreSQL check failed." -ForegroundColor Red
    $allPassed = $false
}

# 3. Check n8n HTTP Health Endpoint
Write-Host "`n[Check 3/6] Testing n8n /healthz Endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:5678/healthz" -Method Get -TimeoutSec 10
    Write-Host "n8n Health Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
    Write-Host "Failed to reach n8n healthz endpoint: $_" -ForegroundColor Red
    $allPassed = $false
}

# 4. Check n8n Web UI Root
Write-Host "`n[Check 4/6] Testing n8n Web Interface (http://127.0.0.1:5678)..." -ForegroundColor Yellow
try {
    $webResponse = Invoke-WebRequest -Uri "http://127.0.0.1:5678/" -Method Get -TimeoutSec 10 -UseBasicParsing
    Write-Host "HTTP Status: $($webResponse.StatusCode)" -ForegroundColor Green
    if ($webResponse.StatusCode -eq 200) {
        Write-Host "n8n UI is online and serving requests." -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to reach n8n web root: $_" -ForegroundColor Red
    $allPassed = $false
}

# 5. Check Docker Volumes Persistence
Write-Host "`n[Check 5/6] Verifying Persistent Docker Volumes..." -ForegroundColor Yellow
$volumes = docker volume ls --format "{{.Name}}"
$hasPgVol = $volumes -contains "sales_agent_postgres_data"
$hasN8nVol = $volumes -contains "sales_agent_n8n_data"
$pgVolColor = if ($hasPgVol) { "Green" } else { "Red" }
$n8nVolColor = if ($hasN8nVol) { "Green" } else { "Red" }
Write-Host "sales_agent_postgres_data volume present: $hasPgVol" -ForegroundColor $pgVolColor
Write-Host "sales_agent_n8n_data volume present:      $hasN8nVol" -ForegroundColor $n8nVolColor
if (-not $hasPgVol -or -not $hasN8nVol) { $allPassed = $false }

# 6. Check Port Isolation
Write-Host "`n[Check 6/6] Verifying PostgreSQL Network Isolation..." -ForegroundColor Yellow
$pgPublished = $pgContainer.Publishers | Where-Object { $_.PublishedPort -and $_.PublishedPort -gt 0 }
if (-not $pgPublished) {
    Write-Host "PostgreSQL port 5432 is NOT exposed to the host (Strictly internal to Docker network)." -ForegroundColor Green
} else {
    Write-Host "WARNING: PostgreSQL port is exposed: $($pgPublished | ConvertTo-Json)" -ForegroundColor Red
    $allPassed = $false
}

Write-Host "`n==================================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host " ALL PHASE 3 VERIFICATIONS PASSED SUCCESSFULLY!   " -ForegroundColor Green
} else {
    Write-Host " ONE OR MORE VERIFICATION CHECKS FAILED!         " -ForegroundColor Red
}
Write-Host "==================================================" -ForegroundColor Cyan
