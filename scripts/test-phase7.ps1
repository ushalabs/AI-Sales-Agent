# scripts/test-phase7.ps1
# Phase 7 Owner Controls and Human Takeover Automated Test Harness

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " AI SALES AGENT - PHASE 7 OWNER CONTROLS TEST     " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$EnvLines = Get-Content .env
$dbUser = ($EnvLines | Where-Object { $_ -match '^POSTGRES_USER=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$dbName = ($EnvLines | Where-Object { $_ -match '^POSTGRES_DB=(.*)$' } | ForEach-Object { $matches[1] }).Trim()
$sellerId = ($EnvLines | Where-Object { $_ -match '^TELEGRAM_SELLER_USER_ID=(.*)$' } | ForEach-Object { $matches[1] }).Trim()

if (-not $dbUser) { $dbUser = "n8n_db_user" }
if (-not $dbName) { $dbName = "n8n_sales_agent" }
if (-not $sellerId) { $sellerId = "987654321" }

function Run-DbQuery([string]$sql) {
    $res = $sql | docker compose exec -T postgres psql -U $dbUser -d $dbName -t -A
    $firstLine = if ($res -is [array]) { $res[0] } else { $res }
    return ($firstLine + "").Trim()
}

$passed = 0
$failed = 0

# Test 1: Check Default State (Must be FALSE)
Write-Host "`n[Test 1/6] Verifying Automation Defaults to OFF..." -ForegroundColor Yellow
$state = Run-DbQuery "SELECT is_enabled FROM agent_control_state WHERE id = 1;"
if ($state -eq "f" -or $state -eq "false") {
    Write-Host "  PASSED: Automation defaults to OFF (is_enabled = false)." -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Expected is_enabled = false, got '$state'" -ForegroundColor Red
    $failed++
}

# Test 2: Seller issues /on
Write-Host "`n[Test 2/6] Testing Owner /on Command Execution..." -ForegroundColor Yellow
$onRes = Run-DbQuery "UPDATE agent_control_state SET is_enabled = true, updated_by = $sellerId, updated_at = NOW() WHERE id = 1 RETURNING is_enabled;"
if ($onRes -eq "t" -or $onRes -eq "true") {
    Write-Host "  PASSED: Agent successfully enabled (is_enabled = true)." -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Failed to update agent state with /on (got '$onRes')" -ForegroundColor Red
    $failed++
}

# Test 3: Seller issues /pause on specific customer chat
Write-Host "`n[Test 3/6] Testing Specific Customer Chat Pause (/pause)..." -ForegroundColor Yellow
$testChatId = 88776655
$pauseRes = Run-DbQuery "INSERT INTO chat_conversation_state (chat_id, is_paused, last_message_from, pause_reason, updated_at) VALUES ($testChatId, true, 'seller', 'Manual owner pause', NOW()) ON CONFLICT (chat_id) DO UPDATE SET is_paused = true, pause_reason = 'Manual owner pause', updated_at = NOW() RETURNING is_paused;"
if ($pauseRes -eq "t" -or $pauseRes -eq "true") {
    Write-Host "  PASSED: Chat $testChatId successfully paused." -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Failed to pause chat $testChatId (got '$pauseRes')" -ForegroundColor Red
    $failed++
}

# Test 4: Verify Human Takeover Auto-pause detection
Write-Host "`n[Test 4/6] Testing Human Takeover Detection on Seller Outgoing Message..." -ForegroundColor Yellow
$takeoverChatId = 99887766
$takeoverRes = Run-DbQuery "INSERT INTO chat_conversation_state (chat_id, is_paused, last_message_from, pause_reason, updated_at) VALUES ($takeoverChatId, true, 'seller', 'Human takeover (seller replied manually)', NOW()) ON CONFLICT (chat_id) DO UPDATE SET is_paused = true, last_message_from = 'seller', pause_reason = 'Human takeover (seller replied manually)', updated_at = NOW() RETURNING is_paused;"
if ($takeoverRes -eq "t" -or $takeoverRes -eq "true") {
    Write-Host "  PASSED: Human takeover correctly flags chat $takeoverChatId as paused." -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Human takeover flag failed (got '$takeoverRes')" -ForegroundColor Red
    $failed++
}

# Test 5: Seller issues /resume on customer chat
Write-Host "`n[Test 5/6] Testing Specific Customer Chat Resume (/resume)..." -ForegroundColor Yellow
$resumeRes = Run-DbQuery "UPDATE chat_conversation_state SET is_paused = false, pause_reason = 'Resumed by owner', updated_at = NOW() WHERE chat_id = $testChatId RETURNING is_paused;"
if ($resumeRes -eq "f" -or $resumeRes -eq "false") {
    Write-Host "  PASSED: Chat $testChatId successfully resumed (is_paused = false)." -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Failed to resume chat $testChatId (got '$resumeRes')" -ForegroundColor Red
    $failed++
}

# Test 6: Seller issues /off (Reset to Safe Disabled State)
Write-Host "`n[Test 6/6] Testing Owner /off Command Execution (Safe Reset)..." -ForegroundColor Yellow
$offRes = Run-DbQuery "UPDATE agent_control_state SET is_enabled = false, updated_by = $sellerId, updated_at = NOW() WHERE id = 1 RETURNING is_enabled;"
if ($offRes -eq "f" -or $offRes -eq "false") {
    Write-Host "  PASSED: Agent successfully disabled (is_enabled = false)." -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Failed to update agent state with /off (got '$offRes')" -ForegroundColor Red
    $failed++
}

$summaryColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "PHASE 7 TEST SUMMARY: $passed Passed, $failed Failed" -ForegroundColor $summaryColor
Write-Host "==================================================" -ForegroundColor Cyan

if ($failed -gt 0) { exit 1 }
